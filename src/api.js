// ── API Base URL ──────────────────────────────────────────────────────────
// Vite proxies /api → http://localhost:3000/api (see vite.config.js)
const BASE = '/api';

// ── API Layer ─────────────────────────────────────────────────────────────
async function apiPost(path, body) {
    const res = await fetch(BASE + path, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
}

async function apiGet(path) {
    const res = await fetch(BASE + path);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
}

export async function startDownload(url, quality, outputDir) {
    return apiPost('/download', {
        url,
        quality,
        subject: 'Study',
        disclaimerAccepted: true,
        ...(outputDir ? { outputDir } : {}),
    });
}

export async function getProgress(downloadId) {
    return apiGet(`/progress/${downloadId}`);
}

export async function cancelDownload(downloadId) {
    return apiPost(`/cancel/${downloadId}`, {});
}

export async function checkYtDlp() {
    return apiPost('/check-ytdlp', {});
}
