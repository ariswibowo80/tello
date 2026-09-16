import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/plan.dart';

/// Shows the "How was your experience?" sheet used when marking a Plan
/// completed. Returns the story text the person wrote (may be empty — a
/// memory without a written story is still valid), or null if they
/// dismissed the sheet without confirming.
Future<String?> showPlanToMomentSheet(BuildContext context, {required Plan plan}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PlanToMomentSheet(plan: plan),
  );
}

class _PlanToMomentSheet extends StatefulWidget {
  const _PlanToMomentSheet({required this.plan});
  final Plan plan;

  @override
  State<_PlanToMomentSheet> createState() => _PlanToMomentSheetState();
}

class _PlanToMomentSheetState extends State<_PlanToMomentSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How was your experience?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Turn this plan into a memory.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('What do you want to remember?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: AppLimits.maxStoryLength,
              decoration: const InputDecoration(
                hintText: 'Liburan keluarga yang awalnya direncanakan 3 bulan akhirnya '
                    'menjadi salah satu liburan terbaik tahun ini.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.planAccent),
                onPressed: () => Navigator.of(context).pop(_controller.text),
                child: const Text('Save as Moment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
