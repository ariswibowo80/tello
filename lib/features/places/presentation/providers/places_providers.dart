import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/domain/entities/moment.dart';
import '../../../moments/presentation/providers/moment_providers.dart';
import '../../../plans/domain/entities/plan.dart';
import '../../../plans/presentation/providers/plan_providers.dart';
import '../../domain/entities/place_summary.dart';
import '../../domain/place_aggregator.dart';

/// One-time reads of a bounded batch of Moments/Plans for client-side
/// aggregation into Places. Firestore has no server-side "group by
/// location" query, and this dataset is expected to stay small for a
/// personal life-timeline app — see README known limitations for what
/// happens once someone has more than this many entries.
const int placesAggregationLimit = 300;

final placesMomentsProvider = FutureProvider.autoDispose<List<Moment>>((ref) async {
  final page = await ref.watch(momentRepositoryProvider).fetchMoments(limit: placesAggregationLimit);
  return page.items;
});

final placesPlansProvider = FutureProvider.autoDispose<List<Plan>>((ref) async {
  final page = await ref.watch(planRepositoryProvider).fetchPlans(limit: placesAggregationLimit);
  return page.items;
});

final visitedPlacesProvider = FutureProvider.autoDispose<List<PlaceSummary>>((ref) async {
  final moments = await ref.watch(placesMomentsProvider.future);
  final plans = await ref.watch(placesPlansProvider.future);
  return buildVisitedPlaces(moments: moments, plans: plans);
});

final plannedPlacesProvider = FutureProvider.autoDispose<List<PlaceSummary>>((ref) async {
  final moments = await ref.watch(placesMomentsProvider.future);
  final plans = await ref.watch(placesPlansProvider.future);
  return buildPlannedPlaces(moments: moments, plans: plans);
});
