const express = require('express');
const cors = require('cors');
const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Storage ───────────────────────────────────────────────────────────────
// Directory where completed downloads are saved.
// Set DOWNLOAD_DIR env var (or mount a Railway volume) to persist across restarts.
const DOWNLOAD_DIR = process.env.DOWNLOAD_DIR || path.join(__dirname, 'downloads');
if (!fs.existsSync(DOWNLOAD_DIR)) fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });

// In-memory store: { [downloadId]: { status, progress, speed, eta, message, filePath, process, url, quality, subject } }
const downloads = {};

// Persisted metadata file
const METADATA_FILE = path.join(__dirname, 'metadata.json');
function loadMetadata() {
    try { return JSON.parse(fs.readFileSync(METADATA_FILE, 'utf8')); }
    catch (_) { return []; }
}
function saveMetadata(meta) {
    fs.writeFileSync(METADATA_FILE, JSON.stringify(meta, null, 2));
}

// ── Quality → yt-dlp format ───────────────────────────────────────────────
function qualityToFormat(quality) {
    switch (quality) {
        case '1080p': return 'bestvideo[height<=1080]+bestaudio/best[height<=1080]';
        case '720p': return 'bestvideo[height<=720]+bestaudio/best[height<=720]';
        case '480p': return 'bestvideo[height<=480]+bestaudio/best[height<=480]';
        case 'Audio Only': return 'bestaudio/best';
        default: return 'bestvideo+bestaudio/best';
    }
}

// ── POST /api/download ────────────────────────────────────────────────────
app.post('/api/download', (req, res) => {
    const { url, quality = '720p', subject = 'Study', disclaimerAccepted, outputDir } = req.body;

    if (!url) return res.status(400).json({ success: false, message: 'URL is required' });

    // Resolve save directory (custom or default)
    let saveDir = DOWNLOAD_DIR;
    if (outputDir && typeof outputDir === 'string' && outputDir.trim()) {
        const candidate = path.resolve(outputDir.trim());
        if (!path.isAbsolute(candidate)) {
            return res.status(400).json({ success: false, message: 'Output directory must be an absolute path' });
        }
        saveDir = candidate;
        if (!fs.existsSync(saveDir)) {
            try { fs.mkdirSync(saveDir, { recursive: true }); }
            catch (_) { return res.status(400).json({ success: false, message: 'Cannot create output directory' }); }
        }
    }

    const downloadId = Date.now().toString();
    const outputTemplate = path.join(saveDir, `${downloadId}.%(ext)s`);
    const format = qualityToFormat(quality);

    // Initialise state
    downloads[downloadId] = {
        status: 'downloading',
        progress: 0,
        speed: '',
        eta: '',
        message: 'Starting download...',
        filePath: null,
        url,
        quality,
        subject,
        title: 'Downloading...',
        startedAt: new Date().toISOString(),
        completedAt: null,
        saveDir,
    };

    // Spawn yt-dlp
    const args = [
        url,
        '--format', format,
        '--output', outputTemplate,
        '--merge-output-format', 'mp4',
        '--newline',         // one progress line per line
        '--no-playlist',
    ];

    const proc = spawn('yt-dlp', args);
    downloads[downloadId].process = proc;

    // Parse yt-dlp stdout
    proc.stdout.on('data', (data) => {
        const lines = data.toString().split('\n').filter(Boolean);
        lines.forEach(line => {
            // [download]  42.6% of 245.30MiB at 2.40MiB/s ETA 00:31
            const dlMatch = line.match(/\[download\]\s+([\d.]+)%\s+of\s+[\d.]+\S+\s+at\s+(\S+)\s+ETA\s+(\S+)/);
            if (dlMatch) {
                downloads[downloadId].progress = parseFloat(dlMatch[1]);
                downloads[downloadId].speed = dlMatch[2];
                downloads[downloadId].eta = dlMatch[3];
                downloads[downloadId].message = 'Downloading...';
            }
            // Destination line — grab title
            const destMatch = line.match(/\[download\] Destination: .+?([^/\\]+)\.mp4/);
            if (destMatch) {
                downloads[downloadId].title = destMatch[1].replace(/^\d+\./, '').trim();
            }
            // Merger line
            if (line.includes('[Merger]') || line.includes('Merging formats')) {
                downloads[downloadId].message = 'Processing...';
            }
        });
    });

    proc.stderr.on('data', (data) => {
        const msg = data.toString();
        if (msg.includes('ERROR')) {
            downloads[downloadId].status = 'error';
            downloads[downloadId].message = msg.slice(0, 200);
        }
    });

    proc.on('close', (code) => {
        const dl = downloads[downloadId];
        if (dl.status === 'cancelled') return;

        if (code === 0) {
            // Find the output file
            const files = fs.readdirSync(dl.saveDir).filter(f => f.startsWith(downloadId));
            const mp4 = files.find(f => f.endsWith('.mp4')) || files[0];

            if (mp4) {
                dl.filePath = path.join(dl.saveDir, mp4);
                dl.status = 'completed';
                dl.progress = 100;
                dl.message = 'Download complete!';
                dl.completedAt = new Date().toISOString();

                // Save metadata
                const meta = loadMetadata();
                meta.unshift({
                    downloadId,
                    title: dl.title,
                    url: dl.url,
                    quality: dl.quality,
                    subject: dl.subject,
                    filePath: dl.filePath,
                    startedAt: dl.startedAt,
                    completedAt: dl.completedAt,
                    fileSizeMb: +(fs.statSync(dl.filePath).size / 1048576).toFixed(1),
                });
                saveMetadata(meta);
            } else {
                dl.status = 'error';
                dl.message = 'Output file not found after download.';
            }
        } else {
            if (dl.status !== 'error') {
                dl.status = 'error';
                dl.message = `yt-dlp exited with code ${code}`;
            }
        }
        delete dl.process;
    });

    res.json({ success: true, downloadId, message: 'Download started' });
});

// ── GET /api/progress/:downloadId ─────────────────────────────────────────
app.get('/api/progress/:downloadId', (req, res) => {
    const dl = downloads[req.params.downloadId];
    if (!dl) return res.status(404).json({ status: 'error', message: 'Download not found' });

    res.json({
        status: dl.status,
        progress: dl.progress,
        speed: dl.speed,
        eta: dl.eta,
        message: dl.message,
    });
});

// ── GET /api/download-file/:downloadId ────────────────────────────────────
app.get('/api/download-file/:downloadId', (req, res) => {
    const dl = downloads[req.params.downloadId];
    if (!dl || !dl.filePath || !fs.existsSync(dl.filePath)) {
        return res.status(404).json({ error: 'File not found or download not complete' });
    }
    const filename = path.basename(dl.filePath);
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Type', 'video/mp4');
    const stream = fs.createReadStream(dl.filePath);
    stream.pipe(res);
    // Delete file from server disk once transfer is complete
    res.on('finish', () => {
        fs.unlink(dl.filePath, () => {});
        delete downloads[downloadId];
    });
});

// ── POST /api/cancel/:downloadId ──────────────────────────────────────────
app.post('/api/cancel/:downloadId', (req, res) => {
    const dl = downloads[req.params.downloadId];
    if (!dl) return res.status(404).json({ error: 'Download not found' });

    if (dl.process) {
        dl.process.kill('SIGTERM');
        delete dl.process;
    }
    dl.status = 'cancelled';
    dl.message = 'Cancelled by user';
    res.json({ success: true });
});

// ── GET /api/metadata ─────────────────────────────────────────────────────
app.get('/api/metadata', (req, res) => {
    res.json(loadMetadata());
});

// ── POST /api/check-ytdlp ─────────────────────────────────────────────────
app.post('/api/check-ytdlp', (req, res) => {
    try {
        const version = execSync('yt-dlp --version', { timeout: 5000 }).toString().trim();
        res.json({ installed: true, version });
    } catch (_) {
        res.json({ installed: false, version: null });
    }
});

// ── Start ──────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n✅  StudyStream backend running on port ${PORT}`);
    console.log(`   Downloads saved to: ${DOWNLOAD_DIR}`);
    console.log(`   Make sure yt-dlp is installed: https://github.com/yt-dlp/yt-dlp\n`);
});
