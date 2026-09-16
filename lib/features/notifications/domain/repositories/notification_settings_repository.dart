import '../entities/notification_settings.dart';

abstract class NotificationSettingsRepository {
  Stream<NotificationSettings> watchSettings();
  Future<void> updateSettings(NotificationSettings settings);
}
