import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/download_repository.dart';
import '../../../data/models/video_item.dart';
import '../../../data/models/download_progress.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadRepository _repo;

  DownloadProvider({DownloadRepository? repo})
      : _repo = repo ?? DownloadRepository();

  // ── UI State ──────────────────────────────────────────────────────────────
  final TextEditingController urlController = TextEditingController();
  String _selectedQuality = '1080p';
  String get selectedQuality => _selectedQuality;

  bool _isStarting = false;
  bool get isStarting => _isStarting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Download State ────────────────────────────────────────────────────────
  /// All items (active + history), newest first
  final List<VideoItem> _items = [];
  List<VideoItem> get items => List.unmodifiable(_items);

  /// Only recent 3 for home screen
  List<VideoItem> get recentItems => _items.take(3).toList();

  /// Active polling timers keyed by downloadId
  final Map<String, Timer> _pollingTimers = {};

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<void> init() async {
    final saved = await _repo.loadItems();
    _items
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  // ── Quality Selection ─────────────────────────────────────────────────────
  void selectQuality(String quality) {
    if (_selectedQuality == quality) return;
    _selectedQuality = quality;
    notifyListeners();
  }

  // ── Start Download ────────────────────────────────────────────────────────
  Future<void> startDownload() async {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      _errorMessage = 'Please paste a YouTube URL first.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _isStarting = true;
    notifyListeners();

    try {
      final downloadId = await _repo.startDownload(
        url: url,
        quality: _selectedQuality,
      );

      final item = VideoItem(
        downloadId: downloadId,
        title: _extractTitleFromUrl(url),
        source: _extractSource(url),
        quality: _selectedQuality,
        status: 'downloading',
        downloadedAt: DateTime.now(),
        progress: 0,
      );

      _items.insert(0, item);
      await _repo.saveItem(item);
      urlController.clear();
      _startPolling(downloadId);
    } catch (e) {
      _errorMessage = 'Failed to start download. Is the server running?';
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  void _startPolling(String downloadId) {
    _pollingTimers[downloadId]?.cancel();
    _pollingTimers[downloadId] = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _poll(downloadId),
    );
  }

  Future<void> _poll(String downloadId) async {
    final progress = await _repo.getProgress(downloadId);
    _updateItem(downloadId, progress);

    if (progress.isCompleted) {
      _pollingTimers[downloadId]?.cancel();
      _pollingTimers.remove(downloadId);
      await _fetchFile(downloadId);
    } else if (progress.isError || progress.isCancelled) {
      _pollingTimers[downloadId]?.cancel();
      _pollingTimers.remove(downloadId);
    }
  }

  void _updateItem(String downloadId, DownloadProgress progress) {
    final idx = _items.indexWhere((e) => e.downloadId == downloadId);
    if (idx == -1) return;

    final updated = _items[idx].copyWith(
      status: progress.isCompleted ? 'completed' : progress.status,
      progress: progress.progress,
    );
    _items[idx] = updated;
    _repo.updateItem(updated);
    notifyListeners();
  }

  Future<void> _fetchFile(String downloadId) async {
    try {
      final externalDir = await getExternalStorageDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      final basePath = externalDir?.path ?? appDir.path;
      final path = '$basePath/$downloadId.mp4';
      await _repo.downloadFile(downloadId, path);

      final idx = _items.indexWhere((e) => e.downloadId == downloadId);
      if (idx == -1) return;
      final updated = _items[idx].copyWith(
        localPath: path,
        status: 'completed',
      );
      _items[idx] = updated;
      await _repo.updateItem(updated);
      notifyListeners();
    } catch (_) {
      final idx = _items.indexWhere((e) => e.downloadId == downloadId);
      if (idx != -1) {
        final failed = _items[idx].copyWith(status: 'error');
        _items[idx] = failed;
        await _repo.updateItem(failed);
      }
      _errorMessage = 'Downloaded on server, but failed to save to this device.';
      notifyListeners();
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  Future<void> cancelDownload(String downloadId) async {
    _pollingTimers[downloadId]?.cancel();
    _pollingTimers.remove(downloadId);
    try {
      await _repo.cancelDownload(downloadId);
    } catch (_) {}
    _updateItem(downloadId,
        const DownloadProgress(status: 'cancelled', progress: 0));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _extractTitleFromUrl(String url) {
    // Placeholder: in a real app fetch from oEmbed / metadata
    return 'Study Video';
  }

  String _extractSource(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'YouTube';
    }
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    for (final t in _pollingTimers.values) {
      t.cancel();
    }
    urlController.dispose();
    super.dispose();
  }
}
