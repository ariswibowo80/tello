import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tello/main.dart' as app;

/// Exercises the spec's critical path end-to-end:
/// Login → Create Plan → Mark as Completed → verify the resulting Moment
/// appears in the Timeline.
///
/// ⚠️ WRITTEN BUT NEVER RUN. There is no Flutter/device runtime in the
/// environment this was built in (see README "Known limitations"), so
/// unlike the Cloud Functions build/emulator-load test and the security
/// rules test suite, none of this — not even basic syntax validity in a
/// running Dart VM — has been verified. Widget finders below (button
/// labels, hint text) were cross-checked against the actual screen source
/// at the time of writing, so they *should* match, but timing-sensitive
/// steps (the Material date picker, bottom sheet animations, Firestore
/// round-trip latency even against a local emulator) are exactly the
/// class of thing that tends to need real-device debugging no amount of
/// careful reading substitutes for. Treat this as a strong starting
/// point, not a passing test.
///
/// MUST be run against the Firebase Local Emulator Suite, never
/// production — this test creates and never cleans up a real account:
///
///   firebase emulators:start --only auth,firestore,storage &
///   flutter test integration_test/app_test.dart \
///     --dart-define=USE_FIREBASE_EMULATOR=true
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);

  testWidgets('Login → Create Plan → Mark as Completed → Moment appears in Timeline',
      (tester) async {
    if (!useEmulator) {
      fail(
        'Refusing to run without --dart-define=USE_FIREBASE_EMULATOR=true — '
        'this test creates a real account and must never point at production Firebase.',
      );
    }

    app.main();
    await tester.pumpAndSettle();

    // Point every Firebase SDK at the local emulator suite. This must
    // happen after Firebase.initializeApp() (done inside app.main()) but
    // before the first Auth/Firestore/Storage call the app makes.
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);

    final testEmail = 'integration-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const testPassword = 'Test1234!';
    final planTitle = 'Integration Test Trip ${DateTime.now().millisecondsSinceEpoch}';

    // --- Sign up (Login screen defaults to sign-in; toggle first) ---
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), testPassword);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Router redirects to Timeline once signed in ---
    expect(find.text('My Life'), findsOneWidget);

    // --- Create a Plan via the central Add sheet ---
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Plan Something'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Liburan keluarga ke Bali'),
      planTitle,
    );
    await tester.tap(find.text('Vacation'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // default Material date picker confirm
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Plan'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Back on Timeline; open the new Plan from the Upcoming rail ---
    expect(find.text(planTitle), findsWidgets);
    await tester.tap(find.text(planTitle).first);
    await tester.pumpAndSettle();

    // --- Mark as Completed → Plan→Moment conversion ---
    await tester.tap(find.widgetWithText(ElevatedButton, 'Mark as Completed'));
    await tester.pumpAndSettle();
    expect(find.text('How was your experience?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'A wonderful test trip.');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save as Moment'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Should now be on the new Moment's detail screen ---
    expect(find.text(planTitle), findsWidgets);

    // --- Back to Timeline; the Plan is now a Moment there ---
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My Life'), findsOneWidget);
    expect(find.text(planTitle), findsWidgets);
  });
}
