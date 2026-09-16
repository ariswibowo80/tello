import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../moments/domain/entities/moment.dart';
import '../../../moments/domain/repositories/moment_repository.dart';
import '../../../moments/presentation/providers/moment_providers.dart';
import '../../domain/entities/timeline_filter.dart';

class MomentsTimelineState {
  const MomentsTimelineState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.cursor,
  });

  final List<Moment> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final Object? cursor;

  MomentsTimelineState copyWith({
    List<Moment>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    Object? cursor,
  }) {
    return MomentsTimelineState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cursor: cursor ?? this.cursor,
    );
  }
}

class MomentsTimelineController extends StateNotifier<MomentsTimelineState> {
  MomentsTimelineController(this._repository, this._filter, this._sort)
      : super(const MomentsTimelineState()) {
    _loadFirstPage();
  }

  final MomentRepository _repository;
  final TimelineFilter _filter;
  final TimelineSort _sort;

  List<String>? get _tagFilter => _filter.kind == TimelineFilterKind.tag && _filter.tag != null
      ? [_filter.tag!]
      : null;

  Future<void> _loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.fetchMoments(
        limit: AppLimits.momentsPageSize,
        oldestFirst: _sort == TimelineSort.oldest,
        tagFilter: _tagFilter,
      );
      state = MomentsTimelineState(
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
      final page = await _repository.fetchMoments(
        cursor: state.cursor,
        limit: AppLimits.momentsPageSize,
        oldestFirst: _sort == TimelineSort.oldest,
        tagFilter: _tagFilter,
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

/// Keyed by (filter, sort) so switching filters starts a fresh paginated
/// list rather than mixing cursors from a different query.
final momentsTimelineProvider = StateNotifierProvider.autoDispose
    .family<MomentsTimelineController, MomentsTimelineState, (TimelineFilter, TimelineSort)>(
  (ref, key) {
    final repository = ref.watch(momentRepositoryProvider);
    return MomentsTimelineController(repository, key.$1, key.$2);
  },
);
