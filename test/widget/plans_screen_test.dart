import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';
import 'package:tello/features/plans/presentation/providers/plan_providers.dart';
import 'package:tello/features/plans/presentation/screens/plans_screen.dart';

import '../fakes/fake_plan_repository.dart';

Plan _samplePlan({PlanStatus status = PlanStatus.confirmed}) {
  final now = DateTime.now();
  return Plan(
    id: 'p1',
    title: 'Bali Family Trip',
    category: PlanCategory.vacation,
    startDate: now.add(const Duration(days: 19)),
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> pumpPlans(WidgetTester tester, FakePlanRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [planRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: PlansScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PlansScreen', () {
    testWidgets('shows the Upcoming empty state by default', (tester) async {
      await pumpPlans(tester, FakePlanRepository());
      expect(find.text('Nothing planned yet'), findsOneWidget);
    });

    testWidgets('renders a plan card when there is active data', (tester) async {
      await pumpPlans(tester, FakePlanRepository(initial: [_samplePlan()]));
      expect(find.text('Bali Family Trip'), findsOneWidget);
    });

    testWidgets('switching to Completed shows its own empty state, not the Upcoming plan',
        (tester) async {
      await pumpPlans(tester, FakePlanRepository(initial: [_samplePlan()]));

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('No completed plans yet'), findsOneWidget);
      expect(find.text('Bali Family Trip'), findsNothing);
    });

    testWidgets('switching to Cancelled shows a cancelled plan', (tester) async {
      final cancelled = _samplePlan(status: PlanStatus.cancelled);
      await pumpPlans(tester, FakePlanRepository(initial: [cancelled]));

      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Bali Family Trip'), findsOneWidget);
      expect(find.text('No cancelled plans'), findsNothing);
    });
  });
}
