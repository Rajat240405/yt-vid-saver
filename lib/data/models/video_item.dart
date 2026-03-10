class VideoItem {
  final String downloadId;
  final String title;
  final String source; // e.g. "MIT OpenCourseWare"
  final String quality; // e.g. "1080p"
  final double? fileSizeMb;
  final DateTime? downloadedAt;
  final String status; // 'downloading', 'completed', 'queued', 'error'
  final String? localPath;
  final double progress;

  const VideoItem({
    required this.downloadId,
    required this.title,
    required this.source,
    required this.quality,
    this.fileSizeMb,
    this.downloadedAt,
    required this.status,
    this.localPath,
    this.progress = 0,
  });

  VideoItem copyWith({
    String? status,
    double? progress,
    String? localPath,
    double? fileSizeMb,
  }) {
    return VideoItem(
      downloadId: downloadId,
      title: title,
      source: source,
      quality: quality,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      downloadedAt: downloadedAt,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() => {
        'downloadId': downloadId,
        'title': title,
        'source': source,
        'quality': quality,
        'fileSizeMb': fileSizeMb,
        'downloadedAt': downloadedAt?.toIso8601String(),
        'status': status,
        'localPath': localPath,
        'progress': progress,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      downloadId: json['downloadId'] as String,
      title: json['title'] as String? ?? 'Unknown',
      source: json['source'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      fileSizeMb: (json['fileSizeMb'] as num?)?.toDouble(),
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'queued',
      localPath: json['localPath'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Human-readable age string
  String get ageLabel {
    if (downloadedAt == null) return '';
    final diff = DateTime.now().difference(downloadedAt!);
    if (diff.inDays >= 1) return '${diff.inDays} days ago';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    return 'Just now';
  }

  /// Human-readable file size string
  String get sizeLabel {
    if (fileSizeMb == null) return '';
    if (fileSizeMb! >= 1024) return '${(fileSizeMb! / 1024).toStringAsFixed(1)} GB';
    return '${fileSizeMb!.toStringAsFixed(0)} MB';
  }
}
