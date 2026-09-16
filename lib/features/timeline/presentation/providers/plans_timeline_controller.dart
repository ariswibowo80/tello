import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../plans/domain/entities/plan.dart';
import '../../../plans/domain/repositories/plan_repository.dart';
import '../../../plans/presentation/providers/plan_providers.dart';

class PlansTimelineState {
  const PlansTimelineState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.cursor,
  });

  final List<Plan> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final Object? cursor;

  PlansTimelineState copyWith({
    List<Plan>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    Object? cursor,
  }) {
    return PlansTimelineState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cursor: cursor ?? this.cursor,
    );
  }
}

/// See [activePlanStatuses] in the Plan domain entity — a "Plans" filter
/// view is about what's still ahead, so completed/cancelled plans are
/// excluded here (they already live on the Timeline as Moments, or are
/// intentionally dropped).

class PlansTimelineController extends StateNotifier<PlansTimelineState> {
  PlansTimelineController(this._repository) : super(const PlansTimelineState()) {
    _loadFirstPage();
  }

  final PlanRepository _repository;

  Future<void> _loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.fetchPlans(
        limit: AppLimits.plansPageSize,
        statusFilter: activePlanStatuses,
      );
      state = PlansTimelineState(
        items: page.items,
        isLoading: false,
        hasMore: page.hasMore,
        cursor: page.cursor,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.fetchPlans(
        cursor: state.cursor,
        limit: AppLimits.plansPageSize,
        statusFilter: activePlanStatuses,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        isLoadingMore: false,
        hasMore: page.hasMore,
        cursor: page.cursor,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.message);
    }
  }

  Future<void> refresh() => _loadFirstPage();
}

final plansTimelineProvider =
    StateNotifierProvider.autoDispose<PlansTimelineController, PlansTimelineState>((ref) {
  final repository = ref.watch(planRepositoryProvider);
  return PlansTimelineController(repository);
});

/// A short "what's next" rail shown above the Moments list when no filter
/// (or the default "All" filter) is active. Deliberately small and
/// non-paginated — the dedicated Plans tab (Phase 7) is where the full
/// list lives.
final upcomingPlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final repository = ref.watch(planRepositoryProvider);
  final page = await repository.fetchPlans(
    limit: 5,
    statusFilter: activePlanStatuses,
  );
  return page.items;
});
