import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../moments/presentation/widgets/moment_card.dart';
import '../../../plans/presentation/widgets/plan_card.dart';
import '../../domain/entities/timeline_filter.dart';
import '../providers/moments_timeline_controller.dart';
import '../providers/plans_timeline_controller.dart';
import '../widgets/timeline_filter_bar.dart';
import '../widgets/timeline_year_header.dart';

final _timelineFilterProvider = StateProvider.autoDispose<TimelineFilter>((ref) => TimelineFilter.all);
final _timelineSortProvider = StateProvider.autoDispose<TimelineSort>((ref) => TimelineSort.newest);

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 400) {
      return;
    }
    final filter = ref.read(_timelineFilterProvider);
    if (filter.kind == TimelineFilterKind.plansOnly) {
      ref.read(plansTimelineProvider.notifier).loadMore();
    } else {
      final sort = ref.read(_timelineSortProvider);
      ref.read(momentsTimelineProvider((filter, sort)).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_timelineFilterProvider);
    final sort = ref.watch(_timelineSortProvider);
    final isPlansOnly = filter.kind == TimelineFilterKind.plansOnly;
    final isAll = filter.kind == TimelineFilterKind.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Life'),
        actions: [
          IconButton(
            tooltip: 'Search Moments',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppRoutes.momentSearch),
          ),
          IconButton(
            tooltip: 'On This Day',
            icon: const Icon(Icons.history_toggle_off_rounded),
            onPressed: () => context.push(AppRoutes.onThisDay),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'life_review') context.push(AppRoutes.lifeReview);
              if (value == 'notifications') context.push(AppRoutes.notificationSettings);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'life_review',
                child: ListTile(
                  leading: Icon(Icons.insights_rounded),
                  title: Text('Life in Review'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'notifications',
                child: ListTile(
                  leading: Icon(Icons.notifications_none_rounded),
                  title: Text('Notifications'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          if (isPlansOnly) {
            await ref.read(plansTimelineProvider.notifier).refresh();
          } else {
            await ref.read(momentsTimelineProvider((filter, sort)).notifier).refresh();
            ref.invalidate(upcomingPlansProvider);
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: TimelineFilterBar(
                selected: filter,
                sort: sort,
                onFilterChanged: (f) => ref.read(_timelineFilterProvider.notifier).state = f,
                onSortChanged: (s) => ref.read(_timelineSortProvider.notifier).state = s,
              ),
            ),
            if (isAll) const SliverToBoxAdapter(child: _UpcomingRail()),
            if (isPlansOnly)
              const _PlansOnlySliver()
            else
              _MomentsSliver(filter: filter, sort: sort),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRail extends ConsumerWidget {
  const _UpcomingRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingPlansProvider);

    return upcoming.when(
      loading: () => const SizedBox(height: 180, child: LoadingState()),
      error: (e, _) => const SizedBox.shrink(),
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Upcoming', style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => PlanCard(
                    plan: plans[i],
                    compact: true,
                    onTap: () => context.push('/plan/${plans[i].id}'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MomentsSliver extends ConsumerWidget {
  const _MomentsSliver({required this.filter, required this.sort});

  final TimelineFilter filter;
  final TimelineSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(momentsTimelineProvider((filter, sort)));

    if (state.isLoading) {
      return const SliverToBoxAdapter(child: LoadingState());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorState(
          message: state.errorMessage!,
          onRetry: () => ref.read(momentsTimelineProvider((filter, sort)).notifier).refresh(),
        ),
      );
    }
    if (state.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'No moments yet',
          message: "You don't need to record every day.\nJust record the moments worth remembering.",
        ),
      );
    }

    final children = <Widget>[];
    int? lastYear;
    for (final moment in state.items) {
      if (moment.startDate.year != lastYear) {
        lastYear = moment.startDate.year;
        children.add(TimelineYearHeader(year: lastYear));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: MomentCard(
          moment: moment,
          onTap: () => context.push('/moment/${moment.id}'),
        ),
      ));
    }
    if (state.isLoadingMore) children.add(const LoadingMoreIndicator());

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}

class _PlansOnlySliver extends ConsumerWidget {
  const _PlansOnlySliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plansTimelineProvider);

    if (state.isLoading) {
      return const SliverToBoxAdapter(child: LoadingState());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorState(
          message: state.errorMessage!,
          onRetry: () => ref.read(plansTimelineProvider.notifier).refresh(),
        ),
      );
    }
    if (state.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.flight_takeoff_rounded,
          title: 'Nothing planned yet',
          message: 'Plan your moments. Live them. Remember them.',
        ),
      );
    }

    final children = <Widget>[
      const SizedBox(height: 12),
      for (final plan in state.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PlanCard(plan: plan, onTap: () => context.push('/plan/${plan.id}')),
        ),
      if (state.isLoadingMore) const LoadingMoreIndicator(),
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}
