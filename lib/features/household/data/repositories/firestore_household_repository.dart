import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_invite.dart';
import '../../domain/repositories/household_repository.dart';

class FirestoreHouseholdRepository implements HouseholdRepository {
  FirestoreHouseholdRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _householdsRef =>
      _firestore.collection(FirestoreCollections.households);

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return _householdsRef.doc(householdId).snapshots().map(
          (snap) => snap.exists ? Household.fromFirestore(snap.id, snap.data()!) : null,
        );
  }

  @override
  Stream<String?> watchOrCreateHouseholdId({required String uid, String? email}) {
    var creating = false;
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .asyncMap((snap) async {
      final existing = snap.data()?['householdId'] as String?;
      if (existing != null) return existing;
      // Not yet created — fire the (idempotent, transaction-guarded)
      // creation and return null for now. The write triggers another
      // snapshot on this same listener, which will carry the new id.
      if (!creating) {
        creating = true;
        try {
          await _createHouseholdFor(uid: uid, email: email);
        } finally {
          creating = false;
        }
      }
      return null;
    });
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUid,
    required String memberEmail,
  }) async {
    try {
      final normalizedEmail = memberEmail.toLowerCase();
      final householdRef = _householdsRef.doc(householdId);
      final memberUserRef = _firestore.collection(FirestoreCollections.users).doc(memberUid);
      // Cleared regardless of its status (pending or already accepted) —
      // leaving a stale invite behind, of either status, is what let a
      // removed member's own accept flow re-surface it as if they'd
      // just been invited again.
      final inviteRef = normalizedEmail.isNotEmpty
          ? householdRef.collection(FirestoreCollections.invites).doc(normalizedEmail)
          : null;

      await _firestore.runTransaction((tx) async {
        tx.update(householdRef, {
          'members': FieldValue.arrayRemove([memberUid]),
          'memberEmails': FieldValue.arrayRemove([normalizedEmail]),
        });
        tx.update(memberUserRef, {
          'householdId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (inviteRef != null) {
          tx.delete(inviteRef);
        }
      });
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  Future<void> _createHouseholdFor({required String uid, String? email}) async {
    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      // Guards against a duplicate household if this races with another
      // caller (e.g. two rapid snapshots) or the user already has one.
      if ((userSnap.data()?['householdId'] as String?) != null) return;

      final householdRef = _householdsRef.doc();
      final normalizedEmail = (email ?? '').toLowerCase();
      tx.set(householdRef, {
        'ownerUid': uid,
        'members': [uid],
        'memberEmails': normalizedEmail.isNotEmpty ? [normalizedEmail] : <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {
        'householdId': householdRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> sendInvite({
    required String householdId,
    required String email,
    required String invitedByUid,
  }) async {
    try {
      final normalizedEmail = email.toLowerCase();
      final invite = HouseholdInvite(
        id: normalizedEmail,
        householdId: householdId,
        email: normalizedEmail,
        invitedByUid: invitedByUid,
        status: InviteStatus.pending,
      );
      // Keyed by the invitee's email (not an auto ID) so security rules
      // can verify "is there a pending invite for my email in this
      // household" with a direct doc lookup, without needing a query.
      await _householdsRef
          .doc(householdId)
          .collection(FirestoreCollections.invites)
          .doc(normalizedEmail)
          .set({
        ...invite.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Stream<List<HouseholdInvite>> watchPendingInvitesForEmail(String email) {
    return _firestore
        .collectionGroup(FirestoreCollections.invites)
        .where('email', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) {
              // parent of the invite doc is the household doc.
              final householdId = d.reference.parent.parent!.id;
              return HouseholdInvite.fromFirestore(d.id, householdId, d.data());
            }).toList());
  }

  @override
  Future<void> acceptInvite({
    required HouseholdInvite invite,
    required String uid,
  }) async {
    try {
      final householdRef = _householdsRef.doc(invite.householdId);
      final inviteRef = householdRef.collection(FirestoreCollections.invites).doc(invite.id);
      final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);

      await _firestore.runTransaction((tx) async {
        tx.update(householdRef, {
          'members': FieldValue.arrayUnion([uid]),
          'memberEmails': FieldValue.arrayUnion([invite.email]),
        });
        tx.update(userRef, {
          'householdId': invite.householdId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(inviteRef, {'status': InviteStatus.accepted.name});
      });
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
