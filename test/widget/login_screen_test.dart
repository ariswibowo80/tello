import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/auth/presentation/providers/auth_providers.dart';
import 'package:tello/features/auth/presentation/screens/login_screen.dart';

import '../fakes/fake_auth_repository.dart';

Future<void> pumpLogin(WidgetTester tester, FakeAuthRepository fakeAuth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fakeAuth)],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows "Welcome back" and "Sign In" by default', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await pumpLogin(tester, fakeAuth);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      fakeAuth.dispose();
    });

    testWidgets('toggling to sign-up changes the title and button label', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await pumpLogin(tester, fakeAuth);

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
      fakeAuth.dispose();
    });

    testWidgets('submitting an empty form shows validation errors', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await pumpLogin(tester, fakeAuth);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      fakeAuth.dispose();
    });

    testWidgets('a valid submission calls the auth repository and clears the form error',
        (tester) async {
      final fakeAuth = FakeAuthRepository();
      await pumpLogin(tester, fakeAuth);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'aris@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(fakeAuth.currentUser?.email, 'aris@example.com');
      expect(find.text('Enter a valid email'), findsNothing);
      fakeAuth.dispose();
    });
  });
}
