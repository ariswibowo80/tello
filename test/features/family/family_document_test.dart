import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/family/domain/entities/family_document.dart';

void main() {
  group('FamilyDocument.fromFirestore / toFirestore', () {
    test('round-trips an image document with no expiry', () {
      final map = {
        'title': 'Foto KK',
        'docType': 'KK',
        'fileUrl': 'https://example.com/kk.jpg',
        'storagePath': 'households/h1/familyMembers/m1/abc.jpg',
        'fileKind': 'image',
      };
      final doc = FamilyDocument.fromFirestore('d1', map);

      expect(doc.id, 'd1');
      expect(doc.title, 'Foto KK');
      expect(doc.fileKind, DocumentFileKind.image);
      expect(doc.expiryDate, isNull);
      expect(doc.isExpired, isFalse);

      final written = doc.toFirestore();
      expect(written['title'], 'Foto KK');
      expect(written['fileKind'], 'image');
      expect(written['expiryDate'], isNull);
    });

    test('round-trips a pdf document with an expiry date', () {
      final expiry = DateTime.now().add(const Duration(days: 10));
      final map = {
        'title': 'STNK',
        'docType': 'STNK',
        'fileUrl': 'https://example.com/stnk.pdf',
        'storagePath': 'households/h1/familyAssets/a1/xyz.pdf',
        'fileKind': 'pdf',
        'expiryDate': Timestamp.fromDate(expiry),
      };
      final doc = FamilyDocument.fromFirestore('d2', map);

      expect(doc.fileKind, DocumentFileKind.pdf);
      expect(doc.expiryDate, isNotNull);
      expect(doc.toFirestore()['expiryDate'], isA<Timestamp>());
    });
  });

  group('FamilyDocument expiry helpers', () {
    FamilyDocument docWithExpiry(DateTime? expiry) => FamilyDocument(
          id: '1',
          title: 'Test',
          docType: 'KTP',
          fileUrl: 'https://example.com/x.jpg',
          storagePath: 'path',
          fileKind: DocumentFileKind.image,
          expiryDate: expiry,
          createdAt: DateTime.now(),
        );

    test('isExpired is true once the expiry date has passed', () {
      final doc = docWithExpiry(DateTime.now().subtract(const Duration(days: 1)));
      expect(doc.isExpired, isTrue);
    });

    test('isExpired is false when there is no expiry date', () {
      expect(docWithExpiry(null).isExpired, isFalse);
    });

    test('isExpiringWithin is true inside the window but false once expired', () {
      final soon = docWithExpiry(DateTime.now().add(const Duration(days: 5)));
      expect(soon.isExpiringWithin(30), isTrue);
      expect(soon.isExpiringWithin(2), isFalse);

      final expired = docWithExpiry(DateTime.now().subtract(const Duration(days: 1)));
      expect(expired.isExpiringWithin(30), isFalse);
    });
  });
}
