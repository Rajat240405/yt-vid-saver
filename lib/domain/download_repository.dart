import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api/download_api.dart';
import '../data/models/download_progress.dart';
import '../data/models/video_item.dart';

class DownloadRepository {
  final DownloadApi _api;
  static const _storageKey = 'download_history';

  DownloadRepository({DownloadApi? api}) : _api = api ?? DownloadApi();

  Future<String> startDownload({
    required String url,
    required String quality,
  }) async {
    return _api.startDownload(url: url, quality: quality);
  }

  Future<DownloadProgress> getProgress(String downloadId) {
    return _api.getProgress(downloadId);
  }

  Future<void> downloadFile(String downloadId, String savePath) {
    return _api.downloadFile(downloadId, savePath);
  }

  Future<void> cancelDownload(String downloadId) {
    return _api.cancelDownload(downloadId);
  }

  /// Persist a VideoItem to SharedPreferences.
  Future<void> saveItem(VideoItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadItems();
    final updated = [item, ...existing.where((e) => e.downloadId != item.downloadId)];
    final encoded = updated.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  /// Update an existing item in history.
  Future<void> updateItem(VideoItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadItems();
    final updated = existing.map((e) => e.downloadId == item.downloadId ? item : e).toList();
    final encoded = updated.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  /// Load all saved VideoItems from SharedPreferences.
  Future<List<VideoItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((e) => VideoItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  /// Clear all saved items (for testing).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Check if yt-dlp is running on the server.
  Future<bool> checkYtDlp() => _api.checkYtDlp();
}
