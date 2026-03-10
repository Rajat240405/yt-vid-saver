class DownloadProgress {
  final String status; // 'queued', 'downloading', 'completed', 'error', 'cancelled'
  final double progress; // 0–100
  final String speed;
  final String eta;
  final String message;

  const DownloadProgress({
    required this.status,
    required this.progress,
    this.speed = '',
    this.eta = '',
    this.message = '',
  });

  factory DownloadProgress.fromJson(Map<String, dynamic> json) {
    return DownloadProgress(
      status: (json['status'] as String? ?? 'queued').toLowerCase(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      speed: json['speed'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isError => status == 'error';
  bool get isCancelled => status == 'cancelled';
  bool get isDownloading => status == 'downloading';
}
