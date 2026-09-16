import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/moment.dart';
import '../../domain/repositories/moment_repository.dart';

class FirestoreMomentRepository implements MomentRepository {
  FirestoreMomentRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  })  : _householdId = householdId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _householdId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _momentsRef => _firestore
      .collection(FirestoreCollections.households)
      .doc(_householdId)
      .collection(FirestoreCollections.moments);

  DocumentReference<Map<String, dynamic>> _planRef(String planId) => _firestore
      .collection(FirestoreCollections.households)
      .doc(_householdId)
      .collection(FirestoreCollections.plans)
      .doc(planId);

  @override
  String newMomentId() => _momentsRef.doc().id;

  @override
  Future<MomentPage> fetchMoments({
    Object? cursor,
    int limit = AppLimits.momentsPageSize,
    bool oldestFirst = false,
    List<String>? tagFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _momentsRef.orderBy(
        'startDate',
        descending: !oldestFirst,
      );

      if (tagFilter != null && tagFilter.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tagFilter);
      }

      if (cursor != null) {
        query = query.startAfterDocument(cursor as DocumentSnapshot<Map<String, dynamic>>);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final items = snapshot.docs.map((d) => Moment.fromFirestore(d.id, d.data())).toList();

      return MomentPage(
        items: items,
        hasMore: snapshot.docs.length == limit,
        cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Stream<Moment?> watchMoment(String momentId) {
    return _momentsRef.doc(momentId).snapshots().map(
          (snap) => snap.exists ? Moment.fromFirestore(snap.id, snap.data()!) : null,
        );
  }

  @override
  Future<Moment> createMoment(Moment moment) async {
    try {
      final data = moment.toFirestore()..['createdAt'] = FieldValue.serverTimestamp();

      final DocumentReference<Map<String, dynamic>> docRef;
      if (moment.id.isNotEmpty) {
        docRef = _momentsRef.doc(moment.id);
        await docRef.set(data);
      } else {
        docRef = await _momentsRef.add(data);
      }

      final snap = await docRef.get();
      return Moment.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> updateMoment(Moment moment) async {
    try {
      await _momentsRef.doc(moment.id).update(moment.toFirestore());
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> deleteMoment(String momentId) async {
    try {
      await _momentsRef.doc(momentId).delete();
      // Note: associated Storage media cleanup is handled by StorageService
      // at the call site (UI layer) so this repository stays focused on
      // Firestore, and by an onDelete Cloud Function as a safety net.
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<List<Moment>> fetchMomentsForYear(int year) async {
    try {
      final start = Timestamp.fromDate(DateTime(year, 1, 1));
      final end = Timestamp.fromDate(DateTime(year + 1, 1, 1));
      final snapshot = await _momentsRef
          .where('startDate', isGreaterThanOrEqualTo: start)
          .where('startDate', isLessThan: end)
          .get();
      return snapshot.docs.map((d) => Moment.fromFirestore(d.id, d.data())).toList();
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<List<Moment>> fetchMomentsOnThisDay(String monthDay) async {
    try {
      final snapshot = await _momentsRef.where('monthDay', isEqualTo: monthDay).get();
      return snapshot.docs.map((d) => Moment.fromFirestore(d.id, d.data())).toList();
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<List<Moment>> fetchAllMomentsForSearch() async {
    try {
      final snapshot = await _momentsRef.orderBy('startDate', descending: true).get();
      return snapshot.docs.map((d) => Moment.fromFirestore(d.id, d.data())).toList();
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<Moment> createMomentFromPlan({
    required String planId,
    required Moment draft,
  }) async {
    try {
      final momentDocRef = _momentsRef.doc();
      final planRef = _planRef(planId);

      await _firestore.runTransaction((tx) async {
        final planSnap = await tx.get(planRef);
        if (!planSnap.exists) {
          throw const NotFoundException('This plan no longer exists.');
        }

        final momentData = draft.toFirestore()
          ..['sourcePlanId'] = planId
          ..['createdAt'] = FieldValue.serverTimestamp();

        tx.set(momentDocRef, momentData);
        tx.update(planRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'convertedToMomentId': momentDocRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final snap = await momentDocRef.get();
      return Moment.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
