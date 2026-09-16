/// Profile fields from `users/{uid}` in Firestore — deliberately separate
/// from [AppUser] (in the auth feature), which represents Firebase Auth
/// identity and never touches Firestore. Keeping them apart means the
/// auth layer stays framework-thin, and profile edits (name, photo,
/// timezone) don't require re-authenticating.
class UserProfile {
  const UserProfile({
    required this.id,
    this.displayName,
    this.email,
    this.photoUrl,
    this.timezone,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? timezone;

  factory UserProfile.fromMap(String id, Map<String, dynamic> map) => UserProfile(
        id: id,
        displayName: map['displayName'] as String?,
        email: map['email'] as String?,
        photoUrl: map['photoUrl'] as String?,
        timezone: map['timezone'] as String?,
      );

  /// Used for the fallback initials shown when there's no profile photo.
  String get initials {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
      return (email?.isNotEmpty == true) ? email![0].toUpperCase() : '?';
    }
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
