import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/moments/domain/entities/moment.dart';
import 'package:tello/features/moments/presentation/providers/moment_providers.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';
import 'package:tello/features/plans/presentation/providers/plan_providers.dart';
import 'package:tello/features/timeline/presentation/screens/timeline_screen.dart';

import '../fakes/fake_moment_repository.dart';
import '../fakes/fake_plan_repository.dart';

Future<void> pumpTimeline(
  WidgetTester tester, {
  FakeMomentRepository? moments,
  FakePlanRepository? plans,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        momentRepositoryProvider.overrideWithValue(moments ?? FakeMomentRepository()),
        planRepositoryProvider.overrideWithValue(plans ?? FakePlanRepository()),
      ],
      // Wrapped directly (not via GoRouter) — every context.push() call in
      // TimelineScreen lives inside an onTap/onPressed callback, none of
      // which this suite triggers, so a full router isn't needed to
      // render the screen itself.
      child: const MaterialApp(home: TimelineScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TimelineScreen', () {
    testWidgets('shows the empty state when there are no moments', (tester) async {
      await pumpTimeline(tester);
      expect(find.text('No moments yet'), findsOneWidget);
    });

    testWidgets('shows a moment grouped under its year when there is data', (tester) async {
      final moment = Moment(
        id: 'm1',
        title: 'Liburan ke Jogja',
        startDate: DateTime(2026, 8, 15),
        createdAt: DateTime(2026, 8, 15),
        updatedAt: DateTime(2026, 8, 15),
      );
      await pumpTimeline(tester, moments: FakeMomentRepository(initial: [moment]));

      expect(find.text('Liburan ke Jogja'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('No moments yet'), findsNothing);
    });

    testWidgets('shows an Upcoming rail when there is an active plan', (tester) async {
      final plan = _samplePlan();
      await pumpTimeline(tester, plans: FakePlanRepository(initial: [plan]));

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text(plan.title), findsOneWidget);
    });

    testWidgets('switching to the Plans filter hides the Moments empty state', (tester) async {
      final plan = _samplePlan();
      await pumpTimeline(tester, plans: FakePlanRepository(initial: [plan]));

      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      // "Plans" filter replaces the Moments list with a Plans list, so
      // the Moments-specific empty state should no longer be present —
      // the plan itself should render instead.
      expect(find.text('No moments yet'), findsNothing);
      expect(find.text(plan.title), findsOneWidget);
    });
  });
}

Plan _samplePlan() {
  final now = DateTime.now();
  return Plan(
    id: 'p1',
    title: 'Bali Family Trip',
    category: PlanCategory.vacation,
    startDate: now.add(const Duration(days: 19)),
    status: PlanStatus.confirmed,
    createdAt: now,
    updatedAt: now,
  );
}
