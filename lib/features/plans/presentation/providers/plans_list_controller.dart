import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/plan.dart';
import '../../domain/repositories/plan_repository.dart';
import 'plan_providers.dart';

/// The three groupings shown on the Plans tab. More granular than
/// [PlanStatus] on purpose — "Idea" vs "Confirmed" is a distinction that
/// matters inside a Plan, but on the browse screen "what's still ahead"
/// vs "done" vs "dropped" is the mental model people actually use.
enum PlansViewFilter { upcoming, completed, cancelled }

extension PlansViewFilterStatuses on PlansViewFilter {
  List<PlanStatus> get statuses {
    switch (this) {
      case PlansViewFilter.upcoming:
        return activePlanStatuses;
      case PlansViewFilter.completed:
        return const [PlanStatus.completed];
      case PlansViewFilter.cancelled:
        return const [PlanStatus.cancelled];
    }
  }
}

class PlansListState {
  const PlansListState({
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

  PlansListState copyWith({
    List<Plan>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    Object? cursor,
  }) {
    return PlansListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cursor: cursor ?? this.cursor,
    );
  }
}

class PlansListController extends StateNotifier<PlansListState> {
  PlansListController(this._repository, this._filter) : super(const PlansListState()) {
    _loadFirstPage();
  }

  final PlanRepository _repository;
  final PlansViewFilter _filter;

  Future<void> _loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.fetchPlans(
        limit: AppLimits.plansPageSize,
        statusFilter: _filter.statuses,
      );
      state = PlansListState(items: page.items, isLoading: false, hasMore: page.hasMore, cursor: page.cursor);
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
        statusFilter: _filter.statuses,
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

final plansListProvider = StateNotifierProvider.autoDispose
    .family<PlansListController, PlansListState, PlansViewFilter>((ref, filter) {
  final repository = ref.watch(planRepositoryProvider);
  return PlansListController(repository, filter);
});
