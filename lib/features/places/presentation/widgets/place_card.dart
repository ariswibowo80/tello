import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/place_summary.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, required this.onTap});

  final PlaceSummary place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = place.latestMomentDate != null
        ? 'Last visited ${place.latestMomentDate!.dayMonth} ${place.latestMomentDate!.year}'
        : place.nextPlanDate != null
            ? 'Next trip ${place.nextPlanDate!.dayMonth} ${place.nextPlanDate!.year}'
            : null;

    return Material(
      color: AppColors.placeAccentLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.placeAccent, shape: BoxShape.circle),
                child: const Icon(Icons.place_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: Theme.of(context).textTheme.titleMedium),
                    if (place.address != null && place.address!.isNotEmpty)
                      Text(
                        place.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(dateLabel, style: const TextStyle(color: AppColors.placeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (place.momentCount > 0) _CountBadge(label: 'Moments', count: place.momentCount),
                  if (place.planCount > 0) _CountBadge(label: 'Plans', count: place.planCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$count $label',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
