import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
    // App Check protects Firestore/Storage/Functions from abuse. Debug
    // provider is used automatically in debug builds via the platform
    // config; see README for release provider setup (Play Integrity / DeviceCheck).
    // await FirebaseAppCheck.instance.activate();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Uses the same navigatorKey as GoRouter so a notification tap can
    // navigate even before any screen's own BuildContext exists yet
    // (background/terminated app launch).
    await NotificationService.instance.initialize(navigatorKey: rootNavigatorKey);
    runApp(const ProviderScope(child: TelloApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class TelloApp extends ConsumerWidget {
  const TelloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Save this device's FCM token whenever someone signs in, so Cloud
    // Functions can target it. ref.listen (not watch) — this is a
    // side effect, not something that should rebuild the widget tree.
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null) {
        NotificationService.instance.saveTokenForUser(next.id);
      }
    });

    return MaterialApp.router(
      title: 'TELLO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
