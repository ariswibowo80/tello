import '../../../moments/domain/entities/moment.dart';

/// "You Planned: N trips, M events" / "You Experienced: N trips, M events"
class YearlyCounts {
  const YearlyCounts({required this.trips, required this.events});
  final int trips;
  final int events;
}

/// The full "Your {year} in Review" summary — see
/// `life_review_aggregator.dart` for how each figure is derived.
class LifeReviewSummary {
  const LifeReviewSummary({
    required this.year,
    required this.tripCount,
    required this.placeCount,
    required this.familyMomentCount,
    required this.photoCount,
    required this.celebrationCount,
    required this.planned,
    required this.experienced,
    this.favoriteMoment,
  });

  final int year;
  final int tripCount;
  final int placeCount;
  final int familyMomentCount;
  final int photoCount;
  final int celebrationCount;
  final YearlyCounts planned;
  final YearlyCounts experienced;
  final Moment? favoriteMoment;

  bool get hasAnyData => tripCount > 0 || placeCount > 0 || familyMomentCount > 0 || photoCount > 0 || celebrationCount > 0;
}
