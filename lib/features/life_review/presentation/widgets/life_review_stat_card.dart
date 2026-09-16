import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LifeReviewStatCard extends StatelessWidget {
  const LifeReviewStatCard({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.primaryLight,
  });

  final String emoji;
  final String value;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
