import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/entities/notification_settings.dart';
import '../providers/notification_settings_providers.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings updated,
  ) async {
    try {
      await ref.read(notificationSettingsRepositoryProvider).updateSettings(updated);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: settingsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e is AppException ? e.message : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Choose which reminders TELLO can send you.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            SwitchListTile(
              title: const Text('Upcoming event reminders'),
              subtitle: const Text('"Your Bali trip is in 7 days ✈️"'),
              value: settings.upcomingEventReminders,
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  _update(context, ref, settings.copyWith(upcomingEventReminders: v)),
            ),
            SwitchListTile(
              title: const Text('Plan reminders'),
              subtitle: const Text('"Your Bali Family Trip starts today!"'),
              value: settings.planReminders,
              activeColor: AppColors.primary,
              onChanged: (v) => _update(context, ref, settings.copyWith(planReminders: v)),
            ),
            SwitchListTile(
              title: const Text('On This Day'),
              subtitle: const Text('"3 years ago, you were in Jogja."'),
              value: settings.onThisDay,
              activeColor: AppColors.primary,
              onChanged: (v) => _update(context, ref, settings.copyWith(onThisDay: v)),
            ),
          ],
        ),
      ),
    );
  }
}
