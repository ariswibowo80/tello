import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/family/domain/entities/family_document.dart';

void main() {
  group('FamilyDocument.fromFirestore / toFirestore', () {
    test('round-trips a single-image document with no expiry', () {
      final map = {
        'title': 'Foto KK',
        'docType': 'KK',
        'files': [
          {'url': 'https://example.com/kk.jpg', 'storagePath': 'households/h1/familyMembers/m1/abc.jpg', 'kind': 'image'},
        ],
      };
      final doc = FamilyDocument.fromFirestore('d1', map);

      expect(doc.id, 'd1');
      expect(doc.title, 'Foto KK');
      expect(doc.files, hasLength(1));
      expect(doc.files.single.kind, DocumentFileKind.image);
      expect(doc.expiryDate, isNull);
      expect(doc.isExpired, isFalse);

      final written = doc.toFirestore();
      expect(written['title'], 'Foto KK');
      expect(written['files'], hasLength(1));
      expect((written['files'] as List).single, {
        'url': 'https://example.com/kk.jpg',
        'storagePath': 'households/h1/familyMembers/m1/abc.jpg',
        'kind': 'image',
      });
      expect(written['expiryDate'], isNull);
    });

    test('round-trips a document with multiple files (front + back) and an expiry date', () {
      final expiry = DateTime.now().add(const Duration(days: 10));
      final map = {
        'title': 'KTP Ayah',
        'docType': 'KTP',
        'files': [
          {'url': 'https://example.com/ktp-depan.jpg', 'storagePath': 'a.jpg', 'kind': 'image'},
          {'url': 'https://example.com/ktp-belakang.jpg', 'storagePath': 'b.jpg', 'kind': 'image'},
        ],
        'expiryDate': Timestamp.fromDate(expiry),
      };
      final doc = FamilyDocument.fromFirestore('d2', map);

      expect(doc.files, hasLength(2));
      expect(doc.expiryDate, isNotNull);
      expect(doc.toFirestore()['files'], hasLength(2));
    });

    test('falls back to a one-item file list for documents saved before multi-file support', () {
      final map = {
        'title': 'STNK',
        'docType': 'STNK',
        'fileUrl': 'https://example.com/stnk.pdf',
        'storagePath': 'households/h1/familyAssets/a1/xyz.pdf',
        'fileKind': 'pdf',
      };
      final doc = FamilyDocument.fromFirestore('d3', map);

      expect(doc.files, hasLength(1));
      expect(doc.files.single.url, 'https://example.com/stnk.pdf');
      expect(doc.files.single.kind, DocumentFileKind.pdf);
    });

    test('defaults to an empty file list when neither files nor legacy fields are present', () {
      final doc = FamilyDocument.fromFirestore('d4', {'title': 'Empty', 'docType': 'Lainnya'});
      expect(doc.files, isEmpty);
    });
  });

  group('FamilyDocument expiry helpers', () {
    FamilyDocument docWithExpiry(DateTime? expiry) => FamilyDocument(
          id: '1',
          title: 'Test',
          docType: 'KTP',
          files: const [
            DocumentFile(url: 'https://example.com/x.jpg', storagePath: 'path', kind: DocumentFileKind.image),
          ],
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
