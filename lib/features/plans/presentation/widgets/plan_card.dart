import 'package:flutter/material.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_chip.dart';
import '../../domain/entities/plan.dart';
import 'plan_category_display.dart';

/// A Plan on the Timeline/Plans tab. Visually distinct from MomentCard —
/// orange accent, countdown, and a progress bar reflecting checklist
/// completion — so upcoming plans never get confused with settled memories.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.compact = false,
  });

  final Plan plan;
  final VoidCallback? onTap;

  /// Compact variant is used in the Timeline's horizontal "Upcoming" rail.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: compact ? 240 : null,
      decoration: BoxDecoration(
        color: AppColors.planAccentLight,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.planAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  plan.startDate.countdownLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(
                plan.startDate.dayMonth,
                style: const TextStyle(color: AppColors.planAccent, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(plan.category.icon, size: 14, color: AppColors.planAccent),
              const SizedBox(width: 4),
              Text(
                plan.category.label,
                style: const TextStyle(color: AppColors.planAccent, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (plan.location != null) ...[
            const SizedBox(height: 6),
            LocationChip(name: plan.location!.name, compact: true),
          ],
          const SizedBox(height: 12),
          if (plan.checklist.isEmpty)
            Text(
              'Status: ${plan.status.label}',
              style: const TextStyle(color: AppColors.planAccent, fontSize: 12, fontWeight: FontWeight.w700),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: plan.progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                valueColor: const AlwaysStoppedAnimation(AppColors.planAccent),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(plan.progress * 100).round()}%',
              style: const TextStyle(color: AppColors.planAccent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card),
    );
  }
}
