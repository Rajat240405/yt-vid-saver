import 'package:dio/dio.dart';
import '../models/download_progress.dart';
import '../../core/config.dart';

class DownloadApi {
  late final Dio _dio;

  DownloadApi() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// Start a download. Returns the downloadId string.
  Future<String> startDownload({
    required String url,
    required String quality,
    String subject = AppConfig.defaultSubject,
    bool disclaimerAccepted = true,
  }) async {
    final response = await _dio.post(
      '/download',
      data: {
        'url': url,
        'quality': quality,
        'subject': subject,
        'disclaimerAccepted': disclaimerAccepted,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['downloadId'] as String;
  }

  /// Poll progress for a given downloadId.
  Future<DownloadProgress> getProgress(String downloadId) async {
    try {
      final response = await _dio.get('/progress/$downloadId');
      return DownloadProgress.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return const DownloadProgress(status: 'error', progress: 0, message: 'Failed to get progress');
    }
  }

  /// Download the completed file to a local path.
  Future<void> downloadFile(String downloadId, String savePath) async {
    await _dio.download(
      '/download-file/$downloadId',
      savePath,
      onReceiveProgress: (count, total) {},
    );
  }

  /// Cancel an active download.
  Future<void> cancelDownload(String downloadId) async {
    await _dio.post('/cancel/$downloadId');
  }

  /// Get saved metadata for all downloads.
  Future<dynamic> getMetadata() async {
    final response = await _dio.get('/metadata');
    return response.data;
  }

  /// Check if yt-dlp is installed on the server.
  Future<bool> checkYtDlp() async {
    try {
      final response = await _dio.post('/check-ytdlp');
      final data = response.data as Map<String, dynamic>;
      return data['installed'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
