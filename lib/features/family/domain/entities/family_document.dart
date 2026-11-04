import 'package:cloud_firestore/cloud_firestore.dart';

/// Suggested document types shown as quick-pick chips in the add-document
/// sheet. Free text is still allowed — [FamilyDocument.docType] is a plain
/// String, not an enum, since the real-world list (KTP, KK, STNK, polis
/// asuransi, ...) is open-ended and varies per family.
class DocumentTypePresets {
  DocumentTypePresets._();

  static const List<String> member = [
    'KTP',
    'KK',
    'Akta Lahir',
    'Paspor',
    'SIM',
    'Ijazah',
    'Asuransi',
    'Lainnya',
  ];

  static const List<String> asset = [
    'Sertifikat',
    'STNK',
    'BPKB',
    'Asuransi',
    'PBB',
    'Lainnya',
  ];
}

enum DocumentFileKind { image, pdf }

/// A single scanned/photographed document attached to a [FamilyMember] or
/// a [FamilyAsset] — e.g. a KTP photo or a scanned STNK PDF. Lives in a
/// `documents` subcollection under its parent, scoped to the household
/// the same way Moments/Plans are.
class FamilyDocument {
  const FamilyDocument({
    required this.id,
    required this.title,
    required this.docType,
    required this.fileUrl,
    required this.storagePath,
    required this.fileKind,
    this.expiryDate,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String docType;
  final String fileUrl;
  final String storagePath;
  final DocumentFileKind fileKind;
  final DateTime? expiryDate;
  final String? notes;
  final DateTime createdAt;

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool isExpiringWithin(int days) {
    if (expiryDate == null) return false;
    final threshold = DateTime.now().add(Duration(days: days));
    return expiryDate!.isBefore(threshold) && !isExpired;
  }

  factory FamilyDocument.fromFirestore(String id, Map<String, dynamic> map) {
    return FamilyDocument(
      id: id,
      title: map['title'] as String? ?? '',
      docType: map['docType'] as String? ?? '',
      fileUrl: map['fileUrl'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      fileKind: (map['fileKind'] as String?) == 'pdf' ? DocumentFileKind.pdf : DocumentFileKind.image,
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'docType': docType,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'fileKind': fileKind.name,
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
