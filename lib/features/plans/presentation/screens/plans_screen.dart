import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../providers/plans_list_controller.dart';
import '../widgets/plan_card.dart';

final _plansViewFilterProvider =
    StateProvider.autoDispose<PlansViewFilter>((ref) => PlansViewFilter.upcoming);

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
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
    final filter = ref.read(_plansViewFilterProvider);
    ref.read(plansListProvider(filter).notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_plansViewFilterProvider);
    final state = ref.watch(plansListProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(plansListProvider(filter).notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Things worth looking forward to.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'Upcoming',
                          selected: filter == PlansViewFilter.upcoming,
                          onTap: () => ref.read(_plansViewFilterProvider.notifier).state = PlansViewFilter.upcoming,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Completed',
                          selected: filter == PlansViewFilter.completed,
                          onTap: () =>
                              ref.read(_plansViewFilterProvider.notifier).state = PlansViewFilter.completed,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Cancelled',
                          selected: filter == PlansViewFilter.cancelled,
                          onTap: () =>
                              ref.read(_plansViewFilterProvider.notifier).state = PlansViewFilter.cancelled,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _PlansSliver(filter: filter, state: state),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TagChip(label: label, selected: selected, onTap: onTap);
  }
}

class _PlansSliver extends ConsumerWidget {
  const _PlansSliver({required this.filter, required this.state});

  final PlansViewFilter filter;
  final PlansListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const SliverToBoxAdapter(child: LoadingState());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorState(
          message: state.errorMessage!,
          onRetry: () => ref.read(plansListProvider(filter).notifier).refresh(),
        ),
      );
    }
    if (state.items.isEmpty) {
      return SliverToBoxAdapter(child: _emptyStateFor(filter));
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

  Widget _emptyStateFor(PlansViewFilter filter) {
    switch (filter) {
      case PlansViewFilter.upcoming:
        return const EmptyState(
          icon: Icons.flight_takeoff_rounded,
          title: 'Nothing planned yet',
          message: 'Tap the + button below to plan your next trip, birthday, or gathering.',
        );
      case PlansViewFilter.completed:
        return const EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'No completed plans yet',
          message: "Plans you mark complete become memories on your Timeline.",
        );
      case PlansViewFilter.cancelled:
        return const EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No cancelled plans',
          message: "That's a good thing.",
        );
    }
  }
}
