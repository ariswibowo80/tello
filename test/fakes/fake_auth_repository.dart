import 'dart:async';

import 'package:tello/features/auth/domain/entities/app_user.dart';
import 'package:tello/features/auth/domain/repositories/auth_repository.dart';

/// In-memory [AuthRepository] for widget tests — no Firebase involved.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _user = initialUser;

  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  void _emit(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final user = AppUser(id: 'fake-uid', email: email);
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> signUpWithEmail({required String email, required String password}) async {
    final user = AppUser(id: 'fake-uid', email: email);
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    const user = AppUser(id: 'fake-uid', email: 'fake@example.com');
    _emit(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    _emit(null);
  }

  @override
  Future<void> deleteAccount() async {
    _emit(null);
  }

  /// Test-only helper — closes the broadcast stream when a test is done.
  void dispose() {
    _controller.close();
  }
}
