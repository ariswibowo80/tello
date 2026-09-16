import '../../../../core/constants/app_constants.dart';
import '../entities/plan.dart';

class PlanPage {
  const PlanPage({required this.items, required this.hasMore, this.cursor});

  final List<Plan> items;
  final bool hasMore;
  final Object? cursor;
}

abstract class PlanRepository {
  /// Allocates a fresh, unused document ID without writing anything.
  /// Used so Inspiration photos can be uploaded to
  /// `users/{uid}/plans/{id}/...` *before* the Plan document is created.
  String newPlanId();

  Future<PlanPage> fetchPlans({
    Object? cursor,
    int limit = 20,
    List<PlanStatus>? statusFilter,
  });

  Stream<Plan?> watchPlan(String planId);

  /// Plans whose `startDate` falls within [year] — backs Life in Review's
  /// "You Planned" breakdown.
  Future<List<Plan>> fetchPlansForYear(int year);

  /// If [plan].id is non-empty (typically from [newPlanId]), the document
  /// is written at that exact ID; otherwise Firestore auto-generates one.
  Future<Plan> createPlan(Plan plan);

  Future<void> updatePlan(Plan plan);

  Future<void> deletePlan(String planId);

  Future<void> updateChecklistItem({
    required String planId,
    required String itemId,
    required bool isDone,
  });

  Future<void> updateStatus({required String planId, required PlanStatus status});
}
