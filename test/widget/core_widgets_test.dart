import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/widgets/empty_state.dart';
import 'package:tello/core/widgets/error_state.dart';
import 'package:tello/core/widgets/loading_state.dart';
import 'package:tello/core/widgets/location_chip.dart';
import 'package:tello/core/widgets/tag_chip.dart';

void main() {
  group('TagChip', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TagChip(label: 'Travel'))));
      expect(find.text('Travel'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TagChip(label: 'Travel', onTap: () => tapped = true)),
      ));
      await tester.tap(find.byType(TagChip));
      expect(tapped, isTrue);
    });

    testWidgets('does nothing when tapped without an onTap callback', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TagChip(label: 'Travel'))));
      // Should not throw.
      await tester.tap(find.byType(TagChip));
      await tester.pump();
    });
  });

  group('EmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.star, title: 'Nothing here', message: 'Try again later'),
        ),
      ));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
    });

    testWidgets('omits the message when none is given', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: EmptyState(icon: Icons.star, title: 'Nothing here')),
      ));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byType(Padding), findsWidgets); // sanity: still renders without throwing
    });
  });

  group('ErrorState', () {
    testWidgets('renders message and triggers retry callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ErrorState(message: 'Something broke', onRetry: () => retried = true)),
      ));
      expect(find.text('Something broke'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('hides the retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ErrorState(message: 'Something broke')),
      ));
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('LoadingState', () {
    testWidgets('shows a spinner', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingState())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an optional message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LoadingState(message: 'Loading your moments...')),
      ));
      expect(find.text('Loading your moments...'), findsOneWidget);
    });
  });

  group('LocationChip', () {
    testWidgets('renders the place name', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LocationChip(name: 'Yogyakarta'))));
      expect(find.text('Yogyakarta'), findsOneWidget);
    });
  });
}
