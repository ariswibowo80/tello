import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/profile/domain/entities/user_profile.dart';

void main() {
  group('UserProfile.initials', () {
    test('uses first+last initials when displayName has two+ parts', () {
      const profile = UserProfile(id: '1', displayName: 'Aris Setiawan');
      expect(profile.initials, 'AS');
    });

    test('uses single initial for a one-word name', () {
      const profile = UserProfile(id: '1', displayName: 'Aris');
      expect(profile.initials, 'A');
    });

    test('falls back to email initial when there is no display name', () {
      const profile = UserProfile(id: '1', email: 'aris@example.com');
      expect(profile.initials, 'A');
    });

    test('falls back to "?" when neither name nor email is set', () {
      const profile = UserProfile(id: '1');
      expect(profile.initials, '?');
    });

    test('collapses extra whitespace between name parts', () {
      const profile = UserProfile(id: '1', displayName: '  Aris   Setiawan  ');
      expect(profile.initials, 'AS');
    });
  });
}
