import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_chip.dart';
import '../../domain/entities/moment.dart';

/// A single Moment on the Timeline. Deliberately warm and photo-forward —
/// this should never read like a task-list row.
class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.moment, this.onTap});

  final Moment moment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = moment.media.isNotEmpty ? moment.media.first : null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumbnail != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: thumbnail.thumbnailUrl ?? thumbnail.url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 72, height: 72, color: AppColors.primaryLight),
                      errorWidget: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.image_not_supported_rounded, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(moment.startDate.dayMonth,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  )),
                          if (moment.location != null) ...[
                            const SizedBox(width: 8),
                            Expanded(child: LocationChip(name: moment.location!.name, compact: true)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        moment.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (moment.description != null && moment.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          moment.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
