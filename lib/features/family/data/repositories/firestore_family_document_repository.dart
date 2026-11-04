import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/repositories/family_document_repository.dart';

class FirestoreFamilyDocumentRepository implements FamilyDocumentRepository {
  FirestoreFamilyDocumentRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  })  : _householdId = householdId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _householdId;
  final FirebaseFirestore _firestore;

  String _parentCollectionName(DocumentParentType type) => switch (type) {
        DocumentParentType.familyMember => FirestoreCollections.familyMembers,
        DocumentParentType.familyAsset => FirestoreCollections.familyAssets,
      };

  CollectionReference<Map<String, dynamic>> _documentsRef(DocumentParentType type, String parentId) {
    return _firestore
        .collection(FirestoreCollections.households)
        .doc(_householdId)
        .collection(_parentCollectionName(type))
        .doc(parentId)
        .collection(FirestoreCollections.documents);
  }

  @override
  String newDocumentId(DocumentParentType parentType, String parentId) =>
      _documentsRef(parentType, parentId).doc().id;

  @override
  Stream<List<FamilyDocument>> watchDocuments(DocumentParentType parentType, String parentId) {
    return _documentsRef(parentType, parentId).orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => FamilyDocument.fromFirestore(d.id, d.data())).toList(),
        );
  }

  @override
  Future<FamilyDocument> createDocument(
    DocumentParentType parentType,
    String parentId,
    FamilyDocument document,
  ) async {
    try {
      final ref = _documentsRef(parentType, parentId);
      final data = document.toFirestore();

      final DocumentReference<Map<String, dynamic>> docRef;
      if (document.id.isNotEmpty) {
        docRef = ref.doc(document.id);
        await docRef.set(data);
      } else {
        docRef = await ref.add(data);
      }

      final snap = await docRef.get();
      return FamilyDocument.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> deleteDocument(DocumentParentType parentType, String parentId, String documentId) async {
    try {
      await _documentsRef(parentType, parentId).doc(documentId).delete();
      // Storage file cleanup + local notification cancellation happen at
      // the UI call site, same convention as Moment/Plan media deletes.
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
