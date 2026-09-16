import '../../moments/domain/entities/moment.dart';
import '../../plans/domain/entities/plan.dart';
import 'entities/place_summary.dart';

/// Groups Moments/Plans into places by matching on a normalized location
/// name. There's no dedicated Firestore `places` collection being written
/// to anywhere yet (Moments/Plans just embed a `GeoLocation`), so rather
/// than add write-time bookkeeping this stays a pure, client-side
/// aggregation over whatever's already been fetched — easy to test, and
/// easy to swap for a real `places` collection later if the dataset
/// outgrows client-side grouping.
String normalizePlaceKey(String name) => name.trim().toLowerCase();

/// Places with at least one Moment there — "everywhere you've been" —
/// sorted by most recently visited first.
List<PlaceSummary> buildVisitedPlaces({
  required List<Moment> moments,
  required List<Plan> plans,
}) {
  final momentsByKey = <String, List<Moment>>{};
  for (final m in moments) {
    final loc = m.location;
    if (loc == null || loc.name.trim().isEmpty) continue;
    momentsByKey.putIfAbsent(normalizePlaceKey(loc.name), () => []).add(m);
  }
  if (momentsByKey.isEmpty) return const [];

  final plansByKey = <String, List<Plan>>{};
  for (final p in plans) {
    final loc = p.location;
    if (loc == null || loc.name.trim().isEmpty) continue;
    plansByKey.putIfAbsent(normalizePlaceKey(loc.name), () => []).add(p);
  }

  final now = DateTime.now();
  final summaries = <PlaceSummary>[];

  momentsByKey.forEach((key, momentsHere) {
    final plansHere = plansByKey[key] ?? const <Plan>[];
    final displayLocation = momentsHere.first.location!;
    final latest = momentsHere.map((m) => m.startDate).reduce((a, b) => a.isAfter(b) ? a : b);

    final upcoming = plansHere
        .where((p) => activePlanStatuses.contains(p.status) && p.startDate.isAfter(now))
        .map((p) => p.startDate);
    final nextPlan = upcoming.isEmpty ? null : upcoming.reduce((a, b) => a.isBefore(b) ? a : b);

    summaries.add(PlaceSummary(
      name: displayLocation.name,
      address: displayLocation.address,
      latitude: displayLocation.latitude,
      longitude: displayLocation.longitude,
      moments: momentsHere,
      plans: plansHere,
      latestMomentDate: latest,
      nextPlanDate: nextPlan,
    ));
  });

  summaries.sort((a, b) => b.latestMomentDate!.compareTo(a.latestMomentDate!));
  return summaries;
}

/// Places with an active Plan but no Moment there yet — "somewhere new" —
/// sorted by soonest upcoming date first. A place already shown under
/// Visited is intentionally excluded here rather than duplicated.
List<PlaceSummary> buildPlannedPlaces({
  required List<Moment> moments,
  required List<Plan> plans,
}) {
  final visitedKeys = moments
      .where((m) => m.location != null && m.location!.name.trim().isNotEmpty)
      .map((m) => normalizePlaceKey(m.location!.name))
      .toSet();

  final plansByKey = <String, List<Plan>>{};
  for (final p in plans) {
    final loc = p.location;
    if (loc == null || loc.name.trim().isEmpty) continue;
    if (!activePlanStatuses.contains(p.status)) continue;
    final key = normalizePlaceKey(loc.name);
    if (visitedKeys.contains(key)) continue;
    plansByKey.putIfAbsent(key, () => []).add(p);
  }
  if (plansByKey.isEmpty) return const [];

  final summaries = <PlaceSummary>[];
  plansByKey.forEach((key, plansHere) {
    final displayLocation = plansHere.first.location!;
    final next = plansHere.map((p) => p.startDate).reduce((a, b) => a.isBefore(b) ? a : b);
    summaries.add(PlaceSummary(
      name: displayLocation.name,
      address: displayLocation.address,
      latitude: displayLocation.latitude,
      longitude: displayLocation.longitude,
      moments: const [],
      plans: plansHere,
      nextPlanDate: next,
    ));
  });

  summaries.sort((a, b) => a.nextPlanDate!.compareTo(b.nextPlanDate!));
  return summaries;
}
