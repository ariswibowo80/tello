import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/moments/domain/entities/moment.dart';
import 'package:tello/features/places/domain/place_aggregator.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';

Moment _moment({required String id, required String place, required DateTime date}) {
  return Moment(
    id: id,
    title: 'Trip to $place',
    startDate: date,
    location: GeoLocation(name: place, latitude: 1, longitude: 1),
    createdAt: date,
    updatedAt: date,
  );
}

Plan _plan({
  required String id,
  required String place,
  required DateTime date,
  PlanStatus status = PlanStatus.confirmed,
}) {
  return Plan(
    id: id,
    title: 'Plan for $place',
    category: PlanCategory.vacation,
    startDate: date,
    status: status,
    location: GeoLocation(name: place, latitude: 2, longitude: 2),
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  final now = DateTime.now();

  group('buildVisitedPlaces', () {
    test('groups moments by normalized (trimmed, lowercased) location name', () {
      final moments = [
        _moment(id: 'm1', place: 'Yogyakarta', date: now.subtract(const Duration(days: 10))),
        _moment(id: 'm2', place: '  yogyakarta ', date: now.subtract(const Duration(days: 2))),
        _moment(id: 'm3', place: 'Bali', date: now.subtract(const Duration(days: 5))),
      ];

      final places = buildVisitedPlaces(moments: moments, plans: const []);

      final yogya = places.firstWhere((p) => p.name.toLowerCase().trim() == 'yogyakarta');
      expect(yogya.momentCount, 2);
    });

    test('excludes moments with no location', () {
      final noLocation = Moment(id: 'm1', title: 'x', startDate: now, createdAt: now, updatedAt: now);
      final places = buildVisitedPlaces(moments: [noLocation], plans: const []);
      expect(places, isEmpty);
    });

    test('latestMomentDate is the most recent moment at that place', () {
      final moments = [
        _moment(id: 'm1', place: 'Bali', date: DateTime(2026, 1, 1)),
        _moment(id: 'm2', place: 'Bali', date: DateTime(2026, 6, 1)),
        _moment(id: 'm3', place: 'Bali', date: DateTime(2026, 3, 1)),
      ];
      final places = buildVisitedPlaces(moments: moments, plans: const []);
      expect(places.single.latestMomentDate, DateTime(2026, 6, 1));
    });

    test('sorts by most recently visited first', () {
      final moments = [
        _moment(id: 'm1', place: 'Bali', date: DateTime(2026, 1, 1)),
        _moment(id: 'm2', place: 'Tokyo', date: DateTime(2026, 6, 1)),
      ];
      final places = buildVisitedPlaces(moments: moments, plans: const []);
      expect(places.map((p) => p.name), ['Tokyo', 'Bali']);
    });

    test('attaches matching plans and counts them', () {
      final moments = [_moment(id: 'm1', place: 'Bali', date: now)];
      final plans = [_plan(id: 'p1', place: 'Bali', date: now.add(const Duration(days: 30)))];
      final places = buildVisitedPlaces(moments: moments, plans: plans);
      expect(places.single.planCount, 1);
    });
  });

  group('buildPlannedPlaces', () {
    test('includes places with an active plan and no prior moment', () {
      final plans = [_plan(id: 'p1', place: 'Seoul', date: now.add(const Duration(days: 60)))];
      final places = buildPlannedPlaces(moments: const [], plans: plans);
      expect(places.single.name, 'Seoul');
      expect(places.single.momentCount, 0);
    });

    test('excludes places already visited', () {
      final moments = [_moment(id: 'm1', place: 'Bali', date: now)];
      final plans = [_plan(id: 'p1', place: 'Bali', date: now.add(const Duration(days: 30)))];
      final places = buildPlannedPlaces(moments: moments, plans: plans);
      expect(places, isEmpty);
    });

    test('excludes completed and cancelled plans', () {
      final plans = [
        _plan(id: 'p1', place: 'Seoul', date: now, status: PlanStatus.completed),
        _plan(id: 'p2', place: 'Lombok', date: now, status: PlanStatus.cancelled),
      ];
      final places = buildPlannedPlaces(moments: const [], plans: plans);
      expect(places, isEmpty);
    });

    test('sorts by soonest upcoming date first', () {
      final plans = [
        _plan(id: 'p1', place: 'Sydney', date: now.add(const Duration(days: 90))),
        _plan(id: 'p2', place: 'Seoul', date: now.add(const Duration(days: 10))),
      ];
      final places = buildPlannedPlaces(moments: const [], plans: plans);
      expect(places.map((p) => p.name), ['Seoul', 'Sydney']);
    });
  });
}
