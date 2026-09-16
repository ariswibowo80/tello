import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/moments/domain/entities/moment.dart';

void main() {
  group('Moment Firestore mapping', () {
    test('round-trips through toFirestore/fromFirestore', () {
      final now = DateTime(2026, 8, 15);
      final moment = Moment(
        id: 'ignored',
        title: 'Liburan keluarga ke Jogja',
        description: 'Liburan keluarga pertama setelah sekian lama.',
        startDate: now,
        endDate: now.add(const Duration(days: 2)),
        location: const GeoLocation(
          name: 'Yogyakarta',
          address: 'Yogyakarta, Indonesia',
          latitude: -7.797,
          longitude: 110.370,
        ),
        tags: const ['travel', 'family'],
        createdAt: now,
        updatedAt: now,
      );

      final map = moment.toFirestore();
      // Simulate what Firestore would store for the server-generated fields.
      map['createdAt'] = Timestamp.fromDate(now);
      map['updatedAt'] = Timestamp.fromDate(now);

      final roundTripped = Moment.fromFirestore('generated-id', map);

      expect(roundTripped.title, moment.title);
      expect(roundTripped.location?.name, 'Yogyakarta');
      expect(roundTripped.tags, moment.tags);
      expect(roundTripped.startDate, moment.startDate);
    });
  });

  group('Moment.monthDayKey', () {
    test('zero-pads month and day', () {
      expect(Moment.monthDayKey(DateTime(2026, 8, 5)), '08-05');
      expect(Moment.monthDayKey(DateTime(2026, 12, 25)), '12-25');
      expect(Moment.monthDayKey(DateTime(2026, 1, 1)), '01-01');
    });

    test('is included in toFirestore and is year-independent', () {
      final now = DateTime(2023, 8, 15);
      final moment = Moment(id: 'm1', title: 'x', startDate: now, createdAt: now, updatedAt: now);
      expect(moment.toFirestore()['monthDay'], '08-15');
      expect(Moment.monthDayKey(DateTime(2019, 8, 15)), Moment.monthDayKey(DateTime(2026, 8, 15)));
    });
  });

  group('MediaItem.fromMap', () {
    test('defaults to image type when unspecified', () {
      final item = MediaItem.fromMap({'url': 'https://x/y.jpg', 'storagePath': 'a/b'});
      expect(item.type, MediaType.image);
    });

    test('parses video type explicitly', () {
      final item = MediaItem.fromMap({
        'url': 'https://x/y.mp4',
        'storagePath': 'a/b',
        'type': 'video',
      });
      expect(item.type, MediaType.video);
    });

    test('round-trips thumbnailStoragePath', () {
      const item = MediaItem(
        url: 'https://x/y.jpg',
        storagePath: 'a/b.jpg',
        type: MediaType.image,
        thumbnailStoragePath: 'a/b_thumb.jpg',
      );
      final roundTripped = MediaItem.fromMap(item.toMap());
      expect(roundTripped.thumbnailStoragePath, 'a/b_thumb.jpg');
    });
  });

  group('Moment.copyWith', () {
    test('appends media without touching other fields', () {
      final now = DateTime(2026, 8, 15);
      final original = Moment(
        id: 'm1',
        title: 'Jogja',
        startDate: now,
        tags: const ['travel'],
        createdAt: now,
        updatedAt: now,
      );
      final newMedia = const MediaItem(url: 'https://x/a.jpg', storagePath: 'a/b', type: MediaType.image);

      final updated = original.copyWith(media: [...original.media, newMedia]);

      expect(updated.media.length, 1);
      expect(updated.title, original.title);
      expect(updated.tags, original.tags);
    });

    test('updates notes independently of other fields', () {
      final now = DateTime(2026, 8, 15);
      final original = Moment(id: 'm1', title: 'Jogja', startDate: now, createdAt: now, updatedAt: now);

      final updated = original.copyWith(notes: 'Bring sunscreen next time');

      expect(updated.notes, 'Bring sunscreen next time');
      expect(updated.title, original.title);
    });

    test('clearNotes actually clears notes to null (regression: plain null was a no-op)', () {
      final now = DateTime(2026, 8, 15);
      final withNotes = Moment(
        id: 'm1',
        title: 'Jogja',
        startDate: now,
        notes: 'Bring sunscreen',
        createdAt: now,
        updatedAt: now,
      );

      // Passing notes: null WITHOUT clearNotes must NOT change anything —
      // that's the standard copyWith "not provided" contract.
      expect(withNotes.copyWith(notes: null).notes, 'Bring sunscreen');

      // clearNotes: true is the explicit way to clear it.
      expect(withNotes.copyWith(clearNotes: true).notes, isNull);
    });
  });
}
