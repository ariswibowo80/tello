/// Domain-level representation of the signed-in user.
/// Deliberately Firebase-free so the rest of the app never depends
/// directly on `firebase_auth` types.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.timezone,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? timezone;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      timezone: map['timezone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'timezone': timezone,
      };
}
