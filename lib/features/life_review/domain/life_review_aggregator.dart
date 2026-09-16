import '../../../core/constants/app_constants.dart';
import '../../moments/domain/entities/moment.dart';
import '../../plans/domain/entities/plan.dart';
import 'entities/life_review_summary.dart';

/// Categories that count as a "trip" rather than an "event" — used for
/// both the Planned (by Plan.category) and Experienced (by Moment tag)
/// breakdowns.
const Set<PlanCategory> _tripCategories = {PlanCategory.vacation, PlanCategory.roadTrip};
const String _travelTag = 'travel';
const String _familyTag = 'family';
const String _celebrationTag = 'celebration';

/// Builds the "Your {year} in Review" summary from a year's Moments and
/// Plans. Deliberately pure and Firebase-free — the two heuristics worth
/// calling out:
///
/// - "Trip" vs "event" for a Moment is decided by whether it's tagged
///   `travel` (there's no separate trip/event flag on Moment itself).
/// - "Favorite Moment" has no explicit favoriting feature yet, so this
///   picks the Moment with the most photos in the year as a reasonable
///   proxy for "most memorable" — ties broken by earliest date.
LifeReviewSummary buildLifeReviewSummary({
  required int year,
  required List<Moment> moments,
  required List<Plan> plans,
}) {
  final tripCount = moments.where((m) => m.tags.contains(_travelTag)).length;
  final placeCount = moments
      .where((m) => m.location != null && m.location!.name.trim().isNotEmpty)
      .map((m) => m.location!.name.trim().toLowerCase())
      .toSet()
      .length;
  final familyMomentCount = moments.where((m) => m.tags.contains(_familyTag)).length;
  final photoCount = moments.fold<int>(
    0,
    (sum, m) => sum + m.media.where((item) => item.type == MediaType.image).length,
  );
  final celebrationCount = moments.where((m) => m.tags.contains(_celebrationTag)).length;

  final plannedTrips = plans.where((p) => _tripCategories.contains(p.category)).length;
  final plannedEvents = plans.length - plannedTrips;

  final experiencedTrips = tripCount;
  final experiencedEvents = moments.length - experiencedTrips;

  Moment? favorite;
  for (final m in moments) {
    if (favorite == null || m.media.length > favorite.media.length) {
      favorite = m;
    } else if (m.media.length == favorite.media.length && m.startDate.isBefore(favorite.startDate)) {
      favorite = m;
    }
  }

  return LifeReviewSummary(
    year: year,
    tripCount: tripCount,
    placeCount: placeCount,
    familyMomentCount: familyMomentCount,
    photoCount: photoCount,
    celebrationCount: celebrationCount,
    planned: YearlyCounts(trips: plannedTrips, events: plannedEvents),
    experienced: YearlyCounts(trips: experiencedTrips, events: experiencedEvents),
    favoriteMoment: favorite,
  );
}
