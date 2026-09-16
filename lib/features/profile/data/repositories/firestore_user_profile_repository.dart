import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({
    required String userId,
    FirebaseFirestore? firestore,
  })  : _userId = userId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection(FirestoreCollections.users).doc(_userId);

  @override
  Stream<UserProfile?> watchProfile() {
    return _docRef.snapshots().map(
          (snap) => snap.exists ? UserProfile.fromMap(snap.id, snap.data()!) : null,
        );
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? timezone,
  }) async {
    try {
      final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (displayName != null) data['displayName'] = displayName;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (timezone != null) data['timezone'] = timezone;
      await _docRef.set(data, SetOptions(merge: true));

      // Keep Firebase Auth's own profile fields in sync too — some
      // platform UI (and any future admin tooling) reads those directly
      // rather than Firestore.
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (displayName != null) await user.updateDisplayName(displayName);
        if (photoUrl != null) await user.updatePhotoURL(photoUrl);
      }
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
