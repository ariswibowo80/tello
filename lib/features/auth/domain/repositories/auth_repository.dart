import '../entities/app_user.dart';

/// Contract for authentication. Firebase is an implementation detail —
/// nothing outside `features/auth/data` should import `firebase_auth`.
abstract class AuthRepository {
  /// Emits the current user (or null when signed out) on every auth change.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithGoogle();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  /// Permanently deletes the user's account. Callers are responsible for
  /// confirming intent with the user before calling this.
  Future<void> deleteAccount();
}
