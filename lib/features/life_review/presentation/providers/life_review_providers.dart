import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/presentation/providers/moment_providers.dart';
import '../../../plans/presentation/providers/plan_providers.dart';
import '../../domain/entities/life_review_summary.dart';
import '../../domain/life_review_aggregator.dart';

final selectedReviewYearProvider = StateProvider.autoDispose<int>((ref) => DateTime.now().year);

final lifeReviewSummaryProvider = FutureProvider.autoDispose<LifeReviewSummary>((ref) async {
  final year = ref.watch(selectedReviewYearProvider);
  final moments = await ref.watch(momentRepositoryProvider).fetchMomentsForYear(year);
  final plans = await ref.watch(planRepositoryProvider).fetchPlansForYear(year);
  return buildLifeReviewSummary(year: year, moments: moments, plans: plans);
});
