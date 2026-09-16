import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/auth/presentation/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows the first page title and a Next button initially', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      expect(find.text('Your Life, Told in Moments.'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
    });

    testWidgets('tapping Next advances through all three pages', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Plan what comes next.'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Build your life story.'), findsOneWidget);
    });

    testWidgets('the last page shows Get Started instead of Next', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });
  });
}
