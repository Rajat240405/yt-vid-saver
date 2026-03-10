import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../providers/download_provider.dart';
import '../widgets/quality_selector.dart';
import '../widgets/download_card.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── AppBar ───────────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: AppColors.border,
              titleSpacing: 20,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'StudyStream',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 24),
                  onPressed: () {},
                  color: AppColors.onSurface,
                  padding: const EdgeInsets.only(right: 8),
                ),
              ],
            ),

            // ── Content ───────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),

                  // ── Download Card ──────────────────────────────────────────
                  _DownloadInputCard(),

                  const SizedBox(height: 28),

                  // ── Recent Downloads Header ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Downloads',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DownloadsScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Recent download items ────────────────────────────────
                  if (provider.recentItems.isEmpty)
                    _EmptyState()
                  else
                    ...provider.recentItems.map(
                      (item) => DownloadCard(
                        key: ValueKey(item.downloadId),
                        item: item,
                        onCancel: item.status == 'downloading'
                            ? () => provider.cancelDownload(item.downloadId)
                            : null,
                      ),
                    ),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Download Input Card ────────────────────────────────────────────────────

class _DownloadInputCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'Study Material Link',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  fontSize: 15,
                ),
          ),
          const SizedBox(height: 10),

          // URL Input
          TextField(
            controller: provider.urlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Paste YouTube Link here...',
            ),
          ),

          // Error message
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Quality Selector
          const QualitySelector(),

          const SizedBox(height: 20),

          // Download Button
          ElevatedButton.icon(
            onPressed: provider.isStarting ? null : () => provider.startDownload(),
            icon: provider.isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 22),
            label: Text(
              provider.isStarting ? 'Starting...' : 'Download Video',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shadowColor: AppColors.primary.withOpacity(0.4),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: AppColors.iconGrey.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No downloads yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.subtitle,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a YouTube link above to get started',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.iconGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
