import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(_toAppUser);
  }

  AppUser? _toAppUser(fb.User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _toAppUser(credential.user)!;
      await _ensureUserProfile(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _toAppUser(credential.user)!;
      await _ensureUserProfile(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = _toAppUser(userCredential.user)!;
      await _ensureUserProfile(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      // Firestore document cleanup for a user's subcollections is handled
      // by a Cloud Function trigger on user deletion (onDelete), since
      // client-side recursive deletes are unsafe/incomplete for large data.
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  /// Creates `users/{uid}` on first login if it doesn't already exist.
  /// Every new user starts as the sole member of their own household —
  /// see HouseholdRepository.acceptInvite for how that changes when they
  /// join a partner's household instead.
  Future<void> _ensureUserProfile(AppUser user) async {
    final docRef = _firestore.collection(FirestoreCollections.users).doc(user.id);
    final snapshot = await docRef.get();
    if (snapshot.exists) return;

    final householdRef = _firestore.collection(FirestoreCollections.households).doc();
    final email = (user.email ?? '').toLowerCase();

    final batch = _firestore.batch();
    batch.set(householdRef, {
      'ownerUid': user.id,
      'members': [user.id],
      'memberEmails': email.isNotEmpty ? [email] : <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(docRef, {
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'householdId': householdRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'timezone': DateTime.now().timeZoneName,
    });
    await batch.commit();
  }
}
