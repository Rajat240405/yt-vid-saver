import { startDownload, getProgress, cancelDownload, checkYtDlp } from './api.js';

// ── State ─────────────────────────────────────────────────────────────────
const state = {
    selectedQuality: '1080p',
    items: [],           // All VideoItem objects
    pollingTimers: {},   // { [downloadId]: intervalId }
};

// ── Persist / Load ────────────────────────────────────────────────────────
function saveItems() {
    localStorage.setItem('ss_downloads', JSON.stringify(state.items));
}

function loadItems() {
    try {
        const raw = localStorage.getItem('ss_downloads');
        state.items = raw ? JSON.parse(raw) : [];
    } catch (_) {
        state.items = [];
    }
}

// Download directory — persisted separately
function getDownloadDir() {
    return localStorage.getItem('ss_download_dir') || '';
}
function setDownloadDir(dir) {
    localStorage.setItem('ss_download_dir', dir);
}

// ── DOM refs ──────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const urlInput = $('url-input');
const errorMsg = $('error-msg');
const btnDownload = $('btn-download');
const btnDownloadTxt = $('btn-download-text');
const btnSpinner = $('btn-download-spinner');
const btnIcon = btnDownload.querySelector('.btn-icon');
const recentList = $('recent-list');
const libraryList = $('library-list');
const homeEmpty = $('home-empty');
const libraryEmpty = $('library-empty');
const libraryCount = $('library-count');
const qualityChips = $('quality-chips');
const dirInput = $('dir-input');

// ── Navigation ────────────────────────────────────────────────────────────
const screens = document.querySelectorAll('.screen');
const navItems = document.querySelectorAll('.nav-item');

function showScreen(name) {
    screens.forEach(s => s.classList.toggle('active', s.id === `screen-${name}`));
    navItems.forEach(n => n.classList.toggle('active', n.dataset.screen === name));
    if (name === 'library') renderLibrary();
}

navItems.forEach(btn => {
    btn.addEventListener('click', () => showScreen(btn.dataset.screen));
});

$('btn-see-all').addEventListener('click', () => showScreen('library'));

// ── Quality chips ─────────────────────────────────────────────────────────
qualityChips.addEventListener('click', e => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    document.querySelectorAll('.chip').forEach(c => c.classList.remove('selected'));
    chip.classList.add('selected');
    state.selectedQuality = chip.dataset.quality;
});

// ── Download button ───────────────────────────────────────────────────────
btnDownload.addEventListener('click', handleDownload);
urlInput.addEventListener('keydown', e => { if (e.key === 'Enter') handleDownload(); });

async function handleDownload() {
    const url = urlInput.value.trim();
    if (!url) {
        showError('Please paste a YouTube URL first.');
        urlInput.focus();
        return;
    }
    if (!/^https?:\/\//i.test(url)) {
        showError('Please enter a valid URL starting with http:// or https://');
        return;
    }

    clearError();
    setLoading(true);

    try {
        const outputDir = getDownloadDir();
        const data = await startDownload(url, state.selectedQuality, outputDir || undefined);
        const downloadId = data.downloadId;

        const item = {
            downloadId,
            title: extractTitle(url),
            source: extractSource(url),
            quality: state.selectedQuality,
            status: 'downloading',
            progress: 0,
            speed: '',
            eta: '',
            downloadedAt: new Date().toISOString(),
            fileSizeMb: null,
        };

        state.items.unshift(item);
        saveItems();
        urlInput.value = '';
        renderRecent();
        startPolling(downloadId);
    } catch (err) {
        showError('Failed to start download. Is the backend server running?');
        console.error(err);
    } finally {
        setLoading(false);
    }
}

// ── Polling ───────────────────────────────────────────────────────────────
function startPolling(downloadId) {
    stopPolling(downloadId);
    state.pollingTimers[downloadId] = setInterval(() => poll(downloadId), 1000);
}

function stopPolling(downloadId) {
    if (state.pollingTimers[downloadId]) {
        clearInterval(state.pollingTimers[downloadId]);
        delete state.pollingTimers[downloadId];
    }
}

async function poll(downloadId) {
    try {
        const p = await getProgress(downloadId);
        const status = (p.status || '').toLowerCase();

        // Store speed + eta into the item for display
        updateItem(downloadId, {
            status,
            progress: p.progress || 0,
            speed: p.speed || '',
            eta: p.eta || '',
        });

        if (status === 'completed' || status === 'error' || status === 'cancelled') {
            stopPolling(downloadId);
        }
    } catch (err) {
        console.warn('Poll failed:', err);
    }
}

function updateItem(downloadId, patch) {
    const idx = state.items.findIndex(i => i.downloadId === downloadId);
    if (idx === -1) return;
    state.items[idx] = { ...state.items[idx], ...patch };
    saveItems();
    renderRecent();
    renderLibrary();
}

// ── Cancel an active download ─────────────────────────────────────────────
async function handleCancel(downloadId) {
    stopPolling(downloadId);
    // optimistically update UI
    updateItem(downloadId, { status: 'cancelled', progress: 0, speed: '', eta: '' });
    try {
        await cancelDownload(downloadId);
    } catch (err) {
        console.warn('Cancel request failed:', err);
    }
}

// ── Render: Recent Downloads (Home) ───────────────────────────────────────
function renderRecent() {
    const recent = state.items.slice(0, 3);
    const isEmpty = recent.length === 0;

    homeEmpty.style.display = isEmpty ? 'flex' : 'none';
    recentList.querySelectorAll('.dl-card').forEach(el => el.remove());

    if (!isEmpty) {
        recent.forEach(item => recentList.appendChild(buildCard(item)));
    }
}

// ── Render: Library ───────────────────────────────────────────────────────
function renderLibrary() {
    const isEmpty = state.items.length === 0;
    libraryEmpty.style.display = isEmpty ? 'flex' : 'none';
    libraryList.querySelectorAll('.dl-card').forEach(el => el.remove());

    if (!isEmpty) {
        libraryCount.textContent = `${state.items.length} video${state.items.length > 1 ? 's' : ''}`;
        libraryCount.classList.remove('hidden');
        state.items.forEach(item => libraryList.appendChild(buildCard(item)));
    } else {
        libraryCount.classList.add('hidden');
    }
}

// ── Build a download card element ─────────────────────────────────────────
function buildCard(item) {
    const isDownloading = item.status === 'downloading';
    const isDone = item.status === 'completed';
    const isQueued = item.status === 'queued';
    const isError = item.status === 'error';
    const isCancelled = item.status === 'cancelled';

    const card = document.createElement('div');
    card.className = 'dl-card';
    card.dataset.id = item.downloadId;

    // Thumb icon
    const thumbIcon = isDownloading
        ? `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`
        : `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polygon points="10 8 16 12 10 16 10 8"/></svg>`;

    // Status badge
    const badge = isDone ? `<span class="badge badge-done">DONE</span>`
        : isQueued ? `<span class="badge badge-queued">QUEUED</span>`
            : isError ? `<span class="badge badge-error">ERROR</span>`
                : isCancelled ? `<span class="badge badge-cancelled">STOPPED</span>`
                    : '';

    // Stop button (only while actively downloading)
    const stopBtn = isDownloading
        ? `<button class="stop-btn" data-id="${item.downloadId}" title="Stop download" aria-label="Stop download">
         <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
           <rect x="3" y="3" width="18" height="18" rx="2"/>
         </svg>
       </button>`
        : '';

    const meta = `${item.source}${item.source ? ' • ' : ''}${item.quality}`;
    const age = (isDone || isCancelled) && item.downloadedAt
        ? `<div class="dl-age">${ageLabel(item.downloadedAt)}</div>`
        : '';

    // Speed + ETA row
    const speedHtml = isDownloading && item.speed
        ? `<div class="dl-speed">
         <span class="dl-speed-value">⬇ ${escHtml(item.speed)}</span>
         ${item.eta ? `<span class="dl-eta">ETA ${escHtml(item.eta)}</span>` : ''}
       </div>`
        : '';

    // Progress bar
    const progressHtml = isDownloading
        ? `<div class="dl-progress-wrap">
         <div class="dl-progress-bar">
           <div class="dl-progress-fill" style="width:${item.progress || 0}%"></div>
         </div>
       </div>`
        : '';

    card.innerHTML = `
    <div class="dl-thumb">
      ${thumbIcon}
      ${isDownloading ? `<div class="dl-thumb-badge">${Math.round(item.progress || 0)}%</div>` : ''}
    </div>
    <div class="dl-info">
      <div class="dl-top">
        <div class="dl-title">${escHtml(item.title)}</div>
        <div class="dl-top-actions">${badge}${stopBtn}</div>
      </div>
      <div class="dl-meta">${escHtml(meta)}</div>
      ${age}
      ${speedHtml}
      ${progressHtml}
    </div>`;

    // Wire up stop button AFTER innerHTML is set
    if (isDownloading) {
        const btn = card.querySelector('.stop-btn');
        btn.addEventListener('click', e => {
            e.stopPropagation();
            handleCancel(item.downloadId);
        });
    }

    return card;
}

// ── yt-dlp check ─────────────────────────────────────────────────────────
$('btn-check-ytdlp').addEventListener('click', async () => {
    const tile = $('btn-check-ytdlp');
    const sub = tile.querySelector('.settings-tile-sub');
    sub.textContent = 'Checking…';
    try {
        const res = await checkYtDlp();
        sub.textContent = res.installed ? `✅ yt-dlp ${res.version}` : '❌ yt-dlp not found';
    } catch {
        sub.textContent = '⚠️ Could not reach server';
    }
    setTimeout(() => { sub.textContent = 'Verify server connectivity'; }, 5000);
});

// ── Download directory input ──────────────────────────────────────────────
if (dirInput) {
    dirInput.value = getDownloadDir();
    dirInput.addEventListener('keydown', e => {
        if (e.key === 'Enter') {
            setDownloadDir(dirInput.value.trim());
            dirInput.blur();
            showDirSaved();
        }
    });
}

const dirSaveBtn = $('dir-save-btn');
if (dirSaveBtn) {
    dirSaveBtn.addEventListener('click', () => {
        if (dirInput) setDownloadDir(dirInput.value.trim());
        showDirSaved();
    });
}

function showDirSaved() {
    const hint = $('dir-saved-hint');
    if (!hint) return;
    hint.classList.remove('hidden');
    setTimeout(() => hint.classList.add('hidden'), 2500);
}

// ── Helpers ───────────────────────────────────────────────────────────────
function showError(msg) {
    errorMsg.textContent = msg;
    errorMsg.classList.remove('hidden');
}
function clearError() {
    errorMsg.textContent = '';
    errorMsg.classList.add('hidden');
}

function setLoading(on) {
    btnDownload.disabled = on;
    btnDownloadTxt.textContent = on ? 'Starting…' : 'Download Video';
    btnIcon.style.display = on ? 'none' : '';
    btnSpinner.classList.toggle('hidden', !on);
}

function extractTitle(url) {
    try {
        const u = new URL(url);
        const v = u.searchParams.get('v');
        if (v) return `YouTube Video (${v})`;
        return u.hostname.replace('www.', '') + u.pathname;
    } catch (_) {
        return 'Study Video';
    }
}

function extractSource(url) {
    try {
        const host = new URL(url).hostname.replace('www.', '');
        if (host.includes('youtube') || host.includes('youtu.be')) return 'YouTube';
        return host;
    } catch (_) {
        return '';
    }
}

function ageLabel(iso) {
    const diff = Date.now() - new Date(iso).getTime();
    const mins = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    if (days >= 1) return `${days} day${days > 1 ? 's' : ''} ago`.toUpperCase();
    if (hours >= 1) return `${hours} hour${hours > 1 ? 's' : ''} ago`.toUpperCase();
    if (mins >= 1) return `${mins} min${mins > 1 ? 's' : ''} ago`.toUpperCase();
    return 'JUST NOW';
}

function escHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// ── Resume active downloads after page refresh ────────────────────────────
function resumePolling() {
    state.items.forEach(item => {
        if (item.status === 'downloading') startPolling(item.downloadId);
    });
}

// ── Init ──────────────────────────────────────────────────────────────────
loadItems();
renderRecent();
resumePolling();
