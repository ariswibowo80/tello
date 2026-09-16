import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/moments/domain/entities/moment.dart';
import 'package:tello/features/moments/presentation/widgets/moment_card.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';
import 'package:tello/features/plans/presentation/widgets/plan_card.dart';

void main() {
  group('MomentCard', () {
    testWidgets('renders title and location', (tester) async {
      final moment = Moment(
        id: 'm1',
        title: 'Liburan ke Jogja',
        startDate: DateTime(2026, 8, 15),
        location: const GeoLocation(name: 'Yogyakarta'),
        createdAt: DateTime(2026, 8, 15),
        updatedAt: DateTime(2026, 8, 15),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MomentCard(moment: moment))));
      expect(find.text('Liburan ke Jogja'), findsOneWidget);
      expect(find.text('Yogyakarta'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final moment = Moment(
        id: 'm1',
        title: 'Test',
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MomentCard(moment: moment, onTap: () => tapped = true)),
      ));
      await tester.tap(find.byType(MomentCard));
      expect(tapped, isTrue);
    });

    testWidgets('does not show a location chip when there is no location', (tester) async {
      final moment = Moment(
        id: 'm1',
        title: 'No place set',
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MomentCard(moment: moment))));
      expect(find.byIcon(Icons.place_rounded), findsNothing);
    });
  });

  group('PlanCard', () {
    testWidgets('shows a progress percentage when there is a checklist', (tester) async {
      final plan = Plan(
        id: 'p1',
        title: 'Bali Trip',
        category: PlanCategory.vacation,
        startDate: DateTime.now().add(const Duration(days: 10)),
        checklist: const [
          ChecklistItem(id: 'c1', title: 'Book flight', isDone: true),
          ChecklistItem(id: 'c2', title: 'Book hotel', isDone: false),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlanCard(plan: plan))));
      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('Status:'), findsNothing);
    });

    testWidgets('shows a status badge instead of a percentage when there is no checklist', (tester) async {
      final plan = Plan(
        id: 'p1',
        title: 'Camping Trip',
        category: PlanCategory.other,
        startDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlanCard(plan: plan))));
      expect(find.text('Status: Idea'), findsOneWidget);
    });

    testWidgets('renders the category label', (tester) async {
      final plan = Plan(
        id: 'p1',
        title: 'Bali Family Trip',
        category: PlanCategory.vacation,
        startDate: DateTime.now().add(const Duration(days: 19)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlanCard(plan: plan))));
      expect(find.text('Vacation'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final plan = Plan(
        id: 'p1',
        title: 'Test Plan',
        category: PlanCategory.other,
        startDate: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PlanCard(plan: plan, onTap: () => tapped = true)),
      ));
      await tester.tap(find.byType(PlanCard));
      expect(tapped, isTrue);
    });
  });
}
