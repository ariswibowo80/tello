import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../moments/presentation/widgets/moment_card.dart';
import '../../domain/entities/life_review_summary.dart';
import '../providers/life_review_providers.dart';
import '../widgets/life_review_stat_card.dart';

class LifeReviewScreen extends ConsumerWidget {
  const LifeReviewScreen({super.key});

  Future<void> _share(LifeReviewSummary summary) async {
    final photoLabel = NumberFormat.decimalPattern('en_US').format(summary.photoCount);
    final lines = [
      'Your ${summary.year} in Review',
      '✈️ ${summary.tripCount} Trips',
      '📍 ${summary.placeCount} Places',
      '👨‍👩‍👧 ${summary.familyMomentCount} Family Moments',
      '📷 $photoLabel Photos',
      '🎉 ${summary.celebrationCount} Celebrations',
    ];
    await Share.share(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedReviewYearProvider);
    final summaryAsync = ref.watch(lifeReviewSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Life in Review')),
      body: Column(
        children: [
          _YearSelector(year: year),
          Expanded(
            child: summaryAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(
                message: e is AppException ? e.message : 'Something went wrong. Please try again.',
                onRetry: () => ref.invalidate(lifeReviewSummaryProvider),
              ),
              data: (summary) {
                if (!summary.hasAnyData) {
                  return const EmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Nothing to review yet',
                    message: 'Add some moments this year, then come back.',
                  );
                }
                return _LifeReviewContent(summary: summary, onShare: () => _share(summary));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YearSelector extends ConsumerWidget {
  const _YearSelector({required this.year});
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGoForward = year < DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => ref.read(selectedReviewYearProvider.notifier).state = year - 1,
          ),
          Text('Your $year', style: Theme.of(context).textTheme.titleLarge),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed:
                canGoForward ? () => ref.read(selectedReviewYearProvider.notifier).state = year + 1 : null,
          ),
        ],
      ),
    );
  }
}

class _LifeReviewContent extends StatelessWidget {
  const _LifeReviewContent({required this.summary, required this.onShare});
  final LifeReviewSummary summary;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final photoLabel = NumberFormat.decimalPattern('en_US').format(summary.photoCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            LifeReviewStatCard(
              emoji: '✈️',
              value: '${summary.tripCount}',
              label: 'Trips',
              color: AppColors.planAccent,
              backgroundColor: AppColors.planAccentLight,
            ),
            LifeReviewStatCard(
              emoji: '📍',
              value: '${summary.placeCount}',
              label: 'Places',
              color: AppColors.placeAccent,
              backgroundColor: AppColors.placeAccentLight,
            ),
            LifeReviewStatCard(
              emoji: '👨‍👩‍👧',
              value: '${summary.familyMomentCount}',
              label: 'Family Moments',
            ),
            LifeReviewStatCard(
              emoji: '📷',
              value: photoLabel,
              label: 'Photos',
            ),
            LifeReviewStatCard(
              emoji: '🎉',
              value: '${summary.celebrationCount}',
              label: 'Celebrations',
              color: AppColors.celebrationAccent,
              backgroundColor: AppColors.celebrationAccentLight,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Planned vs Experienced', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PlanVsExperienceCard(
                title: 'You Planned',
                counts: summary.planned,
                color: AppColors.planAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanVsExperienceCard(
                title: 'You Experienced',
                counts: summary.experienced,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (summary.favoriteMoment != null) ...[
          const SizedBox(height: 24),
          Text('Favorite Moment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          MomentCard(
            moment: summary.favoriteMoment!,
            onTap: () => context.push('/moment/${summary.favoriteMoment!.id}'),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share Your Year'),
          ),
        ),
      ],
    );
  }
}

class _PlanVsExperienceCard extends StatelessWidget {
  const _PlanVsExperienceCard({required this.title, required this.counts, required this.color});
  final String title;
  final YearlyCounts counts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${counts.trips} trips', style: Theme.of(context).textTheme.bodyMedium),
          Text('${counts.events} events', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
