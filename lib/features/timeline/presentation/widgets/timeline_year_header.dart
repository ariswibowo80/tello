import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TimelineYearHeader extends StatelessWidget {
  const TimelineYearHeader({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Text(
            '$year',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}
