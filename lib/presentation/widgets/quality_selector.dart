import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../providers/download_provider.dart';

class QualitySelector extends StatelessWidget {
  const QualitySelector({super.key});

  static const _options = ['1080p', '720p', 'Audio Only'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORMAT QUALITY',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.subtitle,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _options.map((option) {
            final selected = provider.selectedQuality == option;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _QualityChip(
                label: option,
                selected: selected,
                onTap: () => provider.selectQuality(option),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QualityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QualityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipSelected : AppColors.chipUnselected,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.chipSelected : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected
                    ? AppColors.chipTextSelected
                    : AppColors.chipTextUnselected,
              ),
        ),
      ),
    );
  }
}
