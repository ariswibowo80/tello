import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';
import 'package:tello/features/plans/presentation/providers/plans_list_controller.dart';

void main() {
  group('PlansViewFilter.statuses', () {
    test('upcoming maps to every non-terminal status', () {
      expect(PlansViewFilter.upcoming.statuses, activePlanStatuses);
    });

    test('completed maps only to PlanStatus.completed', () {
      expect(PlansViewFilter.completed.statuses, [PlanStatus.completed]);
    });

    test('cancelled maps only to PlanStatus.cancelled', () {
      expect(PlansViewFilter.cancelled.statuses, [PlanStatus.cancelled]);
    });

    test('the three filters never overlap in status coverage', () {
      final upcoming = PlansViewFilter.upcoming.statuses.toSet();
      final completed = PlansViewFilter.completed.statuses.toSet();
      final cancelled = PlansViewFilter.cancelled.statuses.toSet();

      expect(upcoming.intersection(completed), isEmpty);
      expect(upcoming.intersection(cancelled), isEmpty);
      expect(completed.intersection(cancelled), isEmpty);
    });
  });
}
