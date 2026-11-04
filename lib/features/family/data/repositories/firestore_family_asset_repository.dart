import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/family_asset.dart';
import '../../domain/repositories/family_asset_repository.dart';

class FirestoreFamilyAssetRepository implements FamilyAssetRepository {
  FirestoreFamilyAssetRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  })  : _householdId = householdId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _householdId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _assetsRef => _firestore
      .collection(FirestoreCollections.households)
      .doc(_householdId)
      .collection(FirestoreCollections.familyAssets);

  @override
  String newAssetId() => _assetsRef.doc().id;

  @override
  Stream<List<FamilyAsset>> watchAssets() {
    return _assetsRef.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => FamilyAsset.fromFirestore(d.id, d.data())).toList(),
        );
  }

  @override
  Stream<FamilyAsset?> watchAsset(String assetId) {
    return _assetsRef.doc(assetId).snapshots().map(
          (snap) => snap.exists ? FamilyAsset.fromFirestore(snap.id, snap.data()!) : null,
        );
  }

  @override
  Future<FamilyAsset> createAsset(FamilyAsset asset) async {
    try {
      final data = asset.toFirestore()..['createdAt'] = FieldValue.serverTimestamp();

      final DocumentReference<Map<String, dynamic>> docRef;
      if (asset.id.isNotEmpty) {
        docRef = _assetsRef.doc(asset.id);
        await docRef.set(data);
      } else {
        docRef = await _assetsRef.add(data);
      }

      final snap = await docRef.get();
      return FamilyAsset.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> updateAsset(FamilyAsset asset) async {
    try {
      await _assetsRef.doc(asset.id).update(asset.toFirestore());
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    try {
      await _assetsRef.doc(assetId).delete();
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
