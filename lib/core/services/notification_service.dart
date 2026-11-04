import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';

/// Wires up Firebase Cloud Messaging: permission request, token storage,
/// foreground display, and tap-to-navigate for background/terminated
/// launches. FCM does not show a system notification banner while the
/// app is in the foreground on its own — `flutter_local_notifications`
/// is used to surface those.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tello_default',
    'TELLO notifications',
    description: 'Plan reminders and On This Day memories',
    importance: Importance.high,
  );

  /// Call once, early in app startup. [navigatorKey] must be the same key
  /// passed to `GoRouter(navigatorKey: ...)` so notification taps can
  /// navigate even when they arrive from a background/terminated launch,
  /// before any screen's own `BuildContext` exists yet.
  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (_initialized) return;
    _initialized = true;

    // Only used for document-expiry reminders (scheduled client-side via
    // zonedSchedule below) — Plan/On-This-Day pushes stay server-driven
    // via Cloud Functions. Left at the UTC default rather than detecting
    // the device's IANA zone (no package for that here); harmless for
    // day-granularity reminders like these.
    tz_data.initializeTimeZones();

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final path = response.payload;
        if (path != null && path.isNotEmpty) _navigate(navigatorKey, path);
      },
    );

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(navigatorKey, message));

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // The widget tree (and therefore navigatorKey.currentContext) isn't
      // ready yet this early in startup — defer to the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(navigatorKey, initialMessage));
    }
  }

  /// Call after a successful sign-in — saves this device's FCM token onto
  /// the user's profile so `sendDailyNotifications` (Cloud Functions) can
  /// target it. Safe to call repeatedly; `arrayUnion` de-dupes.
  Future<void> saveTokenForUser(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(userId).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best-effort: a missing token just means this device won't get
      // pushes until the next successful call (e.g. next app open).
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'] as String?,
    );
  }

  /// Schedules local "this document is about to expire" reminders —
  /// [AppLimits.documentExpiryReminderDaysFar] and
  /// [AppLimits.documentExpiryReminderDaysClose] days before [expiryDate].
  /// Any reminder date already in the past is silently skipped (e.g. a
  /// document added with an expiry less than 7 days out only gets the
  /// close one, or none at all if it's already overdue). Call
  /// [cancelDocumentExpiryReminders] first when editing a document's
  /// expiry date, to avoid stale duplicate reminders.
  Future<void> scheduleDocumentExpiryReminders({
    required String documentId,
    required String documentTitle,
    required DateTime expiryDate,
  }) async {
    final baseId = documentId.hashCode;
    final reminders = [
      (
        id: baseId,
        fireAt: expiryDate.subtract(const Duration(days: AppLimits.documentExpiryReminderDaysFar)),
        body: '$documentTitle akan kedaluwarsa dalam ${AppLimits.documentExpiryReminderDaysFar} hari.',
      ),
      (
        id: baseId + 1,
        fireAt: expiryDate.subtract(const Duration(days: AppLimits.documentExpiryReminderDaysClose)),
        body: '$documentTitle akan kedaluwarsa dalam ${AppLimits.documentExpiryReminderDaysClose} hari.',
      ),
    ];

    for (final reminder in reminders) {
      if (reminder.fireAt.isBefore(DateTime.now())) continue;
      await _localNotifications.zonedSchedule(
        reminder.id,
        'Dokumen akan kedaluwarsa',
        reminder.body,
        tz.TZDateTime.from(reminder.fireAt, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Raw path string rather than AppRoutes.family — this service is
        // route-agnostic (see _handleTap/_navigate above, which also take
        // raw path strings from Cloud Functions push payloads) and
        // shouldn't import the router.
        payload: '/family',
      );
    }
  }

  /// Cancels both reminders for [documentId], if scheduled. Safe to call
  /// even if nothing was ever scheduled for it (deleted plugin-side as a
  /// no-op).
  Future<void> cancelDocumentExpiryReminders(String documentId) async {
    final baseId = documentId.hashCode;
    await _localNotifications.cancel(baseId);
    await _localNotifications.cancel(baseId + 1);
  }

  void _handleTap(GlobalKey<NavigatorState> navigatorKey, RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null) _navigate(navigatorKey, route);
  }

  void _navigate(GlobalKey<NavigatorState> navigatorKey, String path) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push(path);
  }
}
