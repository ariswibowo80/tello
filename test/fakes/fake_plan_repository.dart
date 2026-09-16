import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';
import 'package:tello/features/plans/domain/repositories/plan_repository.dart';

/// In-memory [PlanRepository] for widget tests — see
/// [FakeMomentRepository] for the same rationale.
class FakePlanRepository implements PlanRepository {
  FakePlanRepository({List<Plan> initial = const []}) : _plans = List.of(initial);

  final List<Plan> _plans;
  int _idCounter = 0;

  @override
  String newPlanId() => 'fake-plan-${_idCounter++}';

  @override
  Future<PlanPage> fetchPlans({
    Object? cursor,
    int limit = 20,
    List<PlanStatus>? statusFilter,
  }) async {
    var items = List<Plan>.from(_plans);
    if (statusFilter != null && statusFilter.isNotEmpty) {
      items = items.where((p) => statusFilter.contains(p.status)).toList();
    }
    items.sort((a, b) => a.startDate.compareTo(b.startDate));
    return PlanPage(items: items.take(limit).toList(), hasMore: false);
  }

  @override
  Stream<Plan?> watchPlan(String planId) {
    final match = _plans.where((p) => p.id == planId);
    return Stream.value(match.isEmpty ? null : match.first);
  }

  @override
  Future<List<Plan>> fetchPlansForYear(int year) async {
    return _plans.where((p) => p.startDate.year == year).toList();
  }

  @override
  Future<Plan> createPlan(Plan plan) async {
    _plans.removeWhere((p) => p.id == plan.id);
    _plans.add(plan);
    return plan;
  }

  @override
  Future<void> updatePlan(Plan plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index != -1) _plans[index] = plan;
  }

  @override
  Future<void> deletePlan(String planId) async {
    _plans.removeWhere((p) => p.id == planId);
  }

  @override
  Future<void> updateChecklistItem({
    required String planId,
    required String itemId,
    required bool isDone,
  }) async {
    final index = _plans.indexWhere((p) => p.id == planId);
    if (index == -1) return;
    final plan = _plans[index];
    final checklist = [
      for (final item in plan.checklist) item.id == itemId ? item.copyWith(isDone: isDone) : item,
    ];
    _plans[index] = plan.copyWith(checklist: checklist);
  }

  @override
  Future<void> updateStatus({required String planId, required PlanStatus status}) async {
    final index = _plans.indexWhere((p) => p.id == planId);
    if (index != -1) _plans[index] = _plans[index].copyWith(status: status);
  }
}
