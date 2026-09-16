import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/repositories/notification_settings_repository.dart';

class FirestoreNotificationSettingsRepository implements NotificationSettingsRepository {
  FirestoreNotificationSettingsRepository({
    required String userId,
    FirebaseFirestore? firestore,
  })  : _userId = userId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _docRef => _firestore
      .collection(FirestoreCollections.users)
      .doc(_userId)
      .collection(FirestoreCollections.settings)
      .doc('notifications');

  @override
  Stream<NotificationSettings> watchSettings() {
    return _docRef.snapshots().map((snap) => NotificationSettings.fromMap(snap.data()));
  }

  @override
  Future<void> updateSettings(NotificationSettings settings) async {
    try {
      await _docRef.set(settings.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
