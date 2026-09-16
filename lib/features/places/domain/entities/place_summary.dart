import '../../../moments/domain/entities/moment.dart';
import '../../../plans/domain/entities/plan.dart';

/// A client-side aggregate: everything at one location, grouped by name.
/// There is no `places` Firestore document behind this (see
/// `place_aggregator.dart` for why) — it's assembled from whatever
/// Moments/Plans were fetched for the Places screen.
class PlaceSummary {
  const PlaceSummary({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    required this.moments,
    required this.plans,
    this.latestMomentDate,
    this.nextPlanDate,
  });

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<Moment> moments;
  final List<Plan> plans;

  /// Most recent Moment date at this place. Null for a "Planned"-only place.
  final DateTime? latestMomentDate;

  /// Soonest upcoming Plan date at this place. Null if there's no active
  /// Plan here.
  final DateTime? nextPlanDate;

  int get momentCount => moments.length;
  int get planCount => plans.length;
  bool get hasCoordinates => latitude != null && longitude != null;
}
