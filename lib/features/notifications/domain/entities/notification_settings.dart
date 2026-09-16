/// The three notification categories from spec:
/// - [upcomingEventReminders]: "Your Bali trip is in 7 days ✈️"
/// - [planReminders]: "Your Bali Family Trip starts today!"
/// - [onThisDay]: "3 years ago, you were in Jogja."
///
/// All default to enabled — notifications should be opt-out, not opt-in,
/// for an app whose whole point is remembering things.
class NotificationSettings {
  const NotificationSettings({
    this.planReminders = true,
    this.onThisDay = true,
    this.upcomingEventReminders = true,
  });

  final bool planReminders;
  final bool onThisDay;
  final bool upcomingEventReminders;

  factory NotificationSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationSettings();
    return NotificationSettings(
      planReminders: map['planReminders'] as bool? ?? true,
      onThisDay: map['onThisDay'] as bool? ?? true,
      upcomingEventReminders: map['upcomingEventReminders'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'planReminders': planReminders,
        'onThisDay': onThisDay,
        'upcomingEventReminders': upcomingEventReminders,
      };

  NotificationSettings copyWith({
    bool? planReminders,
    bool? onThisDay,
    bool? upcomingEventReminders,
  }) {
    return NotificationSettings(
      planReminders: planReminders ?? this.planReminders,
      onThisDay: onThisDay ?? this.onThisDay,
      upcomingEventReminders: upcomingEventReminders ?? this.upcomingEventReminders,
    );
  }
}
