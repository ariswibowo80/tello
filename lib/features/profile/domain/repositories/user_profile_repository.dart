import '../entities/user_profile.dart';

abstract class UserProfileRepository {
  Stream<UserProfile?> watchProfile();

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? timezone,
  });
}
