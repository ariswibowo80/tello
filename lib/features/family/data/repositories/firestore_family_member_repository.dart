import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/repositories/family_member_repository.dart';

class FirestoreFamilyMemberRepository implements FamilyMemberRepository {
  FirestoreFamilyMemberRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  })  : _householdId = householdId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _householdId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _membersRef => _firestore
      .collection(FirestoreCollections.households)
      .doc(_householdId)
      .collection(FirestoreCollections.familyMembers);

  @override
  String newMemberId() => _membersRef.doc().id;

  @override
  Stream<List<FamilyMember>> watchMembers() {
    return _membersRef.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => FamilyMember.fromFirestore(d.id, d.data())).toList(),
        );
  }

  @override
  Stream<FamilyMember?> watchMember(String memberId) {
    return _membersRef.doc(memberId).snapshots().map(
          (snap) => snap.exists ? FamilyMember.fromFirestore(snap.id, snap.data()!) : null,
        );
  }

  @override
  Future<FamilyMember> createMember(FamilyMember member) async {
    try {
      final data = member.toFirestore()..['createdAt'] = FieldValue.serverTimestamp();

      final DocumentReference<Map<String, dynamic>> docRef;
      if (member.id.isNotEmpty) {
        docRef = _membersRef.doc(member.id);
        await docRef.set(data);
      } else {
        docRef = await _membersRef.add(data);
      }

      final snap = await docRef.get();
      return FamilyMember.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> updateMember(FamilyMember member) async {
    try {
      await _membersRef.doc(member.id).update(member.toFirestore());
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> deleteMember(String memberId) async {
    try {
      await _membersRef.doc(memberId).delete();
      // Nested `documents` subcollection docs are orphaned Firestore-side
      // (same tradeoff as Moment/Plan media) — Storage file cleanup for
      // this member's documents is handled at the UI call site before
      // this is invoked, matching FirestoreMomentRepository.deleteMoment.
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
