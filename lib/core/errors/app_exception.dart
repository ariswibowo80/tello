/// Base class for all user-facing exceptions in TELLO.
///
/// Repositories/data sources must catch raw Firebase exceptions and
/// rethrow as an [AppException] subtype with a friendly [message].
/// UI layers should only ever display [message], never the raw error.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException(super.message, {super.cause});
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

class UnknownAppException extends AppException {
  const UnknownAppException(super.message, {super.cause});
}

/// Maps a raw [FirebaseException]-like error code to a friendly
/// [AppException]. Kept dependency-free here; call sites pass in the
/// `code` string from FirebaseAuthException / FirebaseException.
AppException mapFirebaseErrorCode(String code, {Object? cause}) {
  switch (code) {
    case 'permission-denied':
      return PermissionDeniedException(
        "You don't have permission to access this memory.",
        cause: cause,
      );
    case 'not-found':
      return NotFoundException("We couldn't find what you were looking for.", cause: cause);
    case 'unavailable':
    case 'network-request-failed':
      return NetworkException(
        "You're offline. We'll save this and sync when you're back online.",
        cause: cause,
      );
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return const AuthException('Incorrect email or password.');
    case 'email-already-in-use':
      return const AuthException('That email is already registered.');
    case 'weak-password':
      return const AuthException('Please choose a stronger password.');
    case 'invalid-email':
      return const AuthException('That email address looks invalid.');
    case 'too-many-requests':
      return const AuthException('Too many attempts. Please try again later.');
    case 'requires-recent-login':
      return const AuthException(
        'For your security, please sign out and sign in again before doing this.',
      );
    default:
      return UnknownAppException('Something went wrong. Please try again.', cause: cause);
  }
}
