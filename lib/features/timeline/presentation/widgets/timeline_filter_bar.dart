import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/entities/timeline_filter.dart';

class TimelineFilterBar extends StatelessWidget {
  const TimelineFilterBar({
    super.key,
    required this.selected,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final TimelineFilter selected;
  final TimelineSort sort;
  final ValueChanged<TimelineFilter> onFilterChanged;
  final ValueChanged<TimelineSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: TimelineFilter.defaults.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final filter = TimelineFilter.defaults[i];
              return TagChip(
                label: filter.label,
                selected: filter == selected,
                onTap: () => onFilterChanged(filter),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Row(
            children: [
              Text('Sort:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              _SortToggle(
                label: 'Newest',
                selected: sort == TimelineSort.newest,
                onTap: () => onSortChanged(TimelineSort.newest),
              ),
              const SizedBox(width: 6),
              _SortToggle(
                label: 'Oldest',
                selected: sort == TimelineSort.oldest,
                onTap: () => onSortChanged(TimelineSort.oldest),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            decoration: selected ? TextDecoration.underline : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
