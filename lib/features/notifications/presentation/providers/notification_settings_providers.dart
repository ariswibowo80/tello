import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_notification_settings_repository.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/repositories/notification_settings_repository.dart';

final notificationSettingsRepositoryProvider = Provider<NotificationSettingsRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('notificationSettingsRepositoryProvider read while signed out.');
  }
  return FirestoreNotificationSettingsRepository(userId: user.id);
});

final notificationSettingsProvider = StreamProvider<NotificationSettings>((ref) {
  return ref.watch(notificationSettingsRepositoryProvider).watchSettings();
});
