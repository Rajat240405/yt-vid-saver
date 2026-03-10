import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/video_item.dart';

class DownloadCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const DownloadCard({
    super.key,
    required this.item,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = item.status == 'downloading';
    final isDone = item.status == 'completed';
    final isQueued = item.status == 'queued';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            _ThumbnailWidget(item: item),
            const SizedBox(width: 12),
            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDone) _StatusBadge(label: 'DONE', color: AppColors.done, bg: AppColors.doneBg),
                      if (isQueued) _StatusBadge(label: 'QUEUED', color: AppColors.queued, bg: AppColors.queuedBg),
                      if (isDownloading && onCancel != null)
                        GestureDetector(
                          onTap: onCancel,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: AppColors.iconGrey),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.source}${item.source.isNotEmpty ? ' • ' : ''}${item.quality}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtitle,
                          fontSize: 12,
                        ),
                  ),
                  if (isDone && (item.sizeLabel.isNotEmpty || item.ageLabel.isNotEmpty)) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item.sizeLabel.isNotEmpty) item.sizeLabel,
                        if (item.ageLabel.isNotEmpty) item.ageLabel.toUpperCase(),
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.iconGrey,
                            fontSize: 11,
                          ),
                    ),
                  ],
                  if (isDownloading) ...[
                    const SizedBox(height: 8),
                    _ProgressBar(progress: item.progress),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailWidget extends StatelessWidget {
  final VideoItem item;
  const _ThumbnailWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDownloading = item.status == 'downloading';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark background
            Container(color: const Color(0xFF1E293B)),
            // Icon overlay
            Center(
              child: Icon(
                isDownloading ? Icons.downloading_rounded : Icons.play_circle_outline_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 30,
              ),
            ),
            // Progress badge while downloading
            if (isDownloading)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.progress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress / 100,
        backgroundColor: AppColors.progressBg,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        minHeight: 5,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
