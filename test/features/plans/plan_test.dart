import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/constants/app_constants.dart';
import 'package:tello/features/moments/domain/entities/moment.dart';
import 'package:tello/features/plans/domain/entities/plan.dart';

Plan _buildPlan({List<ChecklistItem> checklist = const [], DateTime? startDate}) {
  final now = DateTime.now();
  return Plan(
    id: 'plan-1',
    title: 'Bali Family Trip',
    category: PlanCategory.vacation,
    startDate: startDate ?? now.add(const Duration(days: 19)),
    checklist: checklist,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Plan.progress', () {
    test('returns 0 when checklist is empty', () {
      final plan = _buildPlan();
      expect(plan.progress, 0);
    });

    test('returns fraction of completed items', () {
      final plan = _buildPlan(checklist: [
        const ChecklistItem(id: '1', title: 'Book flight', isDone: true),
        const ChecklistItem(id: '2', title: 'Book hotel', isDone: true),
        const ChecklistItem(id: '3', title: 'Rent car', isDone: false),
        const ChecklistItem(id: '4', title: 'Find restaurants', isDone: false),
      ]);
      expect(plan.progress, 0.5);
    });

    test('returns 1 when all items are done', () {
      final plan = _buildPlan(checklist: [
        const ChecklistItem(id: '1', title: 'Book flight', isDone: true),
      ]);
      expect(plan.progress, 1.0);
    });
  });

  group('Plan.daysUntilStart', () {
    test('is approximately 19 days for a plan 19 days out', () {
      final plan = _buildPlan(startDate: DateTime.now().add(const Duration(days: 19)));
      expect(plan.daysUntilStart, inInclusiveRange(18, 19));
    });
  });

  group('Plan.toMomentDraft', () {
    test('carries over title, dates, location, people, tags, media, notes', () {
      final plan = Plan(
        id: 'plan-42',
        title: 'Bali Family Trip',
        category: PlanCategory.vacation,
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 24),
        location: const GeoLocation(name: 'Bali', latitude: -8.34, longitude: 115.09),
        peopleIds: const ['p1', 'p2'],
        tags: const ['travel', 'family'],
        notes: 'Bring sunscreen',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final draft = plan.toMomentDraft(story: 'Best trip of the year.');

      expect(draft.title, plan.title);
      expect(draft.startDate, plan.startDate);
      expect(draft.endDate, plan.endDate);
      expect(draft.location?.name, 'Bali');
      expect(draft.peopleIds, plan.peopleIds);
      expect(draft.tags, plan.tags);
      expect(draft.notes, plan.notes);
      expect(draft.sourcePlanId, plan.id);
      expect(draft.description, 'Best trip of the year.');
    });

    test('stores null description for an empty or whitespace-only story', () {
      final plan = _buildPlan();
      expect(plan.toMomentDraft(story: '').description, isNull);
      expect(plan.toMomentDraft(story: '   ').description, isNull);
    });
  });

  group('PlanStatusLabel', () {
    test('maps every status to a human-readable label', () {
      expect(PlanStatus.idea.label, 'Idea');
      expect(PlanStatus.planning.label, 'Planning');
      expect(PlanStatus.confirmed.label, 'Confirmed');
      expect(PlanStatus.ongoing.label, 'Ongoing');
      expect(PlanStatus.completed.label, 'Completed');
      expect(PlanStatus.cancelled.label, 'Cancelled');
    });
  });

  group('activePlanStatuses', () {
    test('excludes completed and cancelled', () {
      expect(activePlanStatuses.contains(PlanStatus.completed), isFalse);
      expect(activePlanStatuses.contains(PlanStatus.cancelled), isFalse);
      expect(activePlanStatuses.length, 4);
    });
  });

  group('Plan links (Inspiration)', () {
    test('round-trips through toFirestore/fromFirestore', () {
      final now = DateTime.now();
      final plan = Plan(
        id: 'plan-links',
        title: 'Camping Trip',
        category: PlanCategory.other,
        startDate: now,
        links: const ['https://pinterest.com/board/camping'],
        createdAt: now,
        updatedAt: now,
      );

      final map = plan.toFirestore();
      map['createdAt'] = Timestamp.fromDate(now);
      map['updatedAt'] = Timestamp.fromDate(now);

      final roundTripped = Plan.fromFirestore('id', map);
      expect(roundTripped.links, plan.links);
    });

    test('defaults to an empty list when absent', () {
      final now = DateTime.now();
      final map = Plan(
        id: 'p',
        title: 'T',
        category: PlanCategory.other,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      ).toFirestore()
        ..remove('links')
        ..['createdAt'] = Timestamp.fromDate(now)
        ..['updatedAt'] = Timestamp.fromDate(now);

      final plan = Plan.fromFirestore('id', map);
      expect(plan.links, isEmpty);
    });
  });

  group('Plan.copyWith', () {
    test('updates status without touching other fields', () {
      final now = DateTime.now();
      final original = Plan(
        id: 'p1',
        title: 'Bali Trip',
        category: PlanCategory.vacation,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(status: PlanStatus.confirmed);

      expect(updated.status, PlanStatus.confirmed);
      expect(updated.title, original.title);
      expect(updated.category, original.category);
    });

    test('replaces checklist without touching itinerary', () {
      final now = DateTime.now();
      final original = Plan(
        id: 'p1',
        title: 'Bali Trip',
        category: PlanCategory.vacation,
        startDate: now,
        itinerary: [ItineraryItem(id: 'i1', date: now, title: 'Arrive')],
        createdAt: now,
        updatedAt: now,
      );

      final newChecklist = [const ChecklistItem(id: 'c1', title: 'Book flight')];
      final updated = original.copyWith(checklist: newChecklist);

      expect(updated.checklist, newChecklist);
      expect(updated.itinerary.length, 1);
    });

    test('clearNotes actually clears notes to null (regression: plain null was a no-op)', () {
      final now = DateTime.now();
      final withNotes = Plan(
        id: 'p1',
        title: 'Bali Trip',
        category: PlanCategory.vacation,
        startDate: now,
        notes: 'Bring sunscreen',
        createdAt: now,
        updatedAt: now,
      );

      expect(withNotes.copyWith(notes: null).notes, 'Bring sunscreen');
      expect(withNotes.copyWith(clearNotes: true).notes, isNull);
    });
  });
}
