import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/family/domain/entities/family_asset.dart';

void main() {
  group('FamilyAsset.fromFirestore / toFirestore', () {
    test('round-trips all fields', () {
      final map = {
        'name': 'Toyota Avanza',
        'category': 'vehicle',
        'purchaseDate': Timestamp.fromDate(DateTime(2022, 3, 1)),
        'estimatedValue': 180000000,
        'photoUrl': 'https://example.com/car.jpg',
        'notes': 'Plat B 1234 ABC',
      };
      final asset = FamilyAsset.fromFirestore('a1', map);

      expect(asset.id, 'a1');
      expect(asset.name, 'Toyota Avanza');
      expect(asset.category, AssetCategory.vehicle);
      expect(asset.purchaseDate, DateTime(2022, 3, 1));
      expect(asset.estimatedValue, 180000000);
      expect(asset.notes, 'Plat B 1234 ABC');

      final written = asset.toFirestore();
      expect(written['name'], 'Toyota Avanza');
      expect(written['category'], 'vehicle');
      expect(written['estimatedValue'], 180000000);
    });

    test('falls back to "other" category for unknown/missing value', () {
      final asset = FamilyAsset.fromFirestore('a2', {'name': 'X'});
      expect(asset.category, AssetCategory.other);
      expect(asset.estimatedValue, isNull);
      expect(asset.purchaseDate, isNull);
    });
  });

  group('FamilyAsset.copyWith', () {
    test('clears estimatedValue only when clearEstimatedValue is true', () {
      final asset = FamilyAsset(
        id: '1',
        name: 'Rumah Jakarta',
        category: AssetCategory.house,
        estimatedValue: 500000000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final unchanged = asset.copyWith(name: 'Rumah Jakarta 2');
      expect(unchanged.estimatedValue, 500000000);

      final cleared = asset.copyWith(clearEstimatedValue: true);
      expect(cleared.estimatedValue, isNull);
    });
  });
}
