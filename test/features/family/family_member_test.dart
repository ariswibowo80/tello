import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/family/domain/entities/family_member.dart';

void main() {
  group('FamilyMember.fromFirestore / toFirestore', () {
    test('round-trips all fields', () {
      final map = {
        'name': 'Budi Santoso',
        'relationship': 'spouse',
        'birthDate': Timestamp.fromDate(DateTime(1990, 5, 20)),
        'photoUrl': 'https://example.com/photo.jpg',
        'notes': 'Alergi kacang',
      };
      final member = FamilyMember.fromFirestore('m1', map);

      expect(member.id, 'm1');
      expect(member.name, 'Budi Santoso');
      expect(member.relationship, FamilyRelationship.spouse);
      expect(member.birthDate, DateTime(1990, 5, 20));
      expect(member.photoUrl, 'https://example.com/photo.jpg');
      expect(member.notes, 'Alergi kacang');

      final written = member.toFirestore();
      expect(written['name'], 'Budi Santoso');
      expect(written['relationship'], 'spouse');
      expect(written['birthDate'], isA<Timestamp>());
    });

    test('falls back to "other" relationship for unknown/missing value', () {
      final member = FamilyMember.fromFirestore('m2', {'name': 'X'});
      expect(member.relationship, FamilyRelationship.other);
      expect(member.birthDate, isNull);
    });
  });

  group('FamilyMember.age', () {
    test('null when birthDate is not set', () {
      final member = FamilyMember(
        id: '1',
        name: 'X',
        relationship: FamilyRelationship.other,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(member.age, isNull);
    });

    test('computes whole years, accounting for birthday not yet reached this year', () {
      final now = DateTime.now();
      // A birthday later this year than today means last birthday was
      // (now.year - 1 - birthYear) years ago, not (now.year - birthYear).
      final futureMonthDay = DateTime(now.year - 30, now.month, now.day).add(const Duration(days: 2));
      final member = FamilyMember(
        id: '1',
        name: 'X',
        relationship: FamilyRelationship.other,
        birthDate: futureMonthDay,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(member.age, 29);
    });
  });

  group('FamilyMember.initials', () {
    test('two-part name returns first + last initials', () {
      final member = FamilyMember(
        id: '1',
        name: 'Budi Santoso',
        relationship: FamilyRelationship.other,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(member.initials, 'BS');
    });

    test('falls back to "?" for an empty name', () {
      final member = FamilyMember(
        id: '1',
        name: '',
        relationship: FamilyRelationship.other,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(member.initials, '?');
    });
  });
}
