import '../entities/family_document.dart';

/// Which parent collection a [FamilyDocument] belongs under —
/// `households/{householdId}/{parentCollection}/{parentId}/documents`.
enum DocumentParentType { familyMember, familyAsset }

abstract class FamilyDocumentRepository {
  String newDocumentId(DocumentParentType parentType, String parentId);

  Stream<List<FamilyDocument>> watchDocuments(DocumentParentType parentType, String parentId);

  Future<FamilyDocument> createDocument(
    DocumentParentType parentType,
    String parentId,
    FamilyDocument document,
  );

  Future<void> deleteDocument(DocumentParentType parentType, String parentId, String documentId);
}
