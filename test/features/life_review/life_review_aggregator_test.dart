import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/life_review/domain/life_review_aggregator.dart';
import 'package:tello/features/moments/domain/entities/moment.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';

Moment _moment({
  required String id,
  required DateTime date,
  List<String> tags = const [],
  String? place,
  int photoCount = 0,
}) {
  return Moment(
    id: id,
    title: 'm-$id',
    startDate: date,
    tags: tags,
    location: place != null ? GeoLocation(name: place) : null,
    media: List.generate(
      photoCount,
      (i) => const MediaItem(url: 'https://x/y.jpg', storagePath: 'a/b', type: MediaType.image),
    ),
    createdAt: date,
    updatedAt: date,
  );
}

Plan _plan({required String id, required DateTime date, required PlanCategory category}) {
  return Plan(id: id, title: 'p-$id', category: category, startDate: date, createdAt: date, updatedAt: date);
}

void main() {
  final y = DateTime(2026, 6, 1);

  group('buildLifeReviewSummary', () {
    test('counts trips by the "travel" tag', () {
      final moments = [
        _moment(id: '1', date: y, tags: const ['travel']),
        _moment(id: '2', date: y, tags: const ['family']),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: moments, plans: const []);
      expect(summary.tripCount, 1);
    });

    test('counts distinct places case/whitespace-insensitively', () {
      final moments = [
        _moment(id: '1', date: y, place: 'Bali'),
        _moment(id: '2', date: y, place: ' bali '),
        _moment(id: '3', date: y, place: 'Tokyo'),
        _moment(id: '4', date: y),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: moments, plans: const []);
      expect(summary.placeCount, 2);
    });

    test('counts photos across all moments (images only)', () {
      final moments = [
        _moment(id: '1', date: y, photoCount: 3),
        _moment(id: '2', date: y, photoCount: 2),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: moments, plans: const []);
      expect(summary.photoCount, 5);
    });

    test('splits planned plans into trips vs events by category', () {
      final plans = [
        _plan(id: '1', date: y, category: PlanCategory.vacation),
        _plan(id: '2', date: y, category: PlanCategory.roadTrip),
        _plan(id: '3', date: y, category: PlanCategory.birthday),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: const [], plans: plans);
      expect(summary.planned.trips, 2);
      expect(summary.planned.events, 1);
    });

    test('splits experienced moments into trips vs events by travel tag', () {
      final moments = [
        _moment(id: '1', date: y, tags: const ['travel']),
        _moment(id: '2', date: y, tags: const ['celebration']),
        _moment(id: '3', date: y),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: moments, plans: const []);
      expect(summary.experienced.trips, 1);
      expect(summary.experienced.events, 2);
    });

    test('favorite moment is the one with the most photos', () {
      final moments = [
        _moment(id: '1', date: y, photoCount: 1),
        _moment(id: '2', date: y, photoCount: 5),
        _moment(id: '3', date: y, photoCount: 2),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: moments, plans: const []);
      expect(summary.favoriteMoment?.id, '2');
    });

    test('favorite moment ties are broken by earliest date', () {
      final moments = [
        _moment(id: 'later', date: DateTime(2026, 8, 1), photoCount: 2),
        _moment(id: 'earlier', date: DateTime(2026, 2, 1), photoCount: 2),
      ];
      final summary = buildLifeReviewSummary(year: 2026, moments: moments, plans: const []);
      expect(summary.favoriteMoment?.id, 'earlier');
    });

    test('favoriteMoment is null and hasAnyData is false for an empty year', () {
      final summary = buildLifeReviewSummary(year: 2026, moments: const [], plans: const []);
      expect(summary.favoriteMoment, isNull);
      expect(summary.hasAnyData, isFalse);
    });
  });
}
