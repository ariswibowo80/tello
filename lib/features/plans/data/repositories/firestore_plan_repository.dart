import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/plan.dart';
import '../../domain/repositories/plan_repository.dart';

class FirestorePlanRepository implements PlanRepository {
  FirestorePlanRepository({
    required String householdId,
    FirebaseFirestore? firestore,
  })  : _householdId = householdId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _householdId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _plansRef => _firestore
      .collection(FirestoreCollections.households)
      .doc(_householdId)
      .collection(FirestoreCollections.plans);

  @override
  String newPlanId() => _plansRef.doc().id;

  @override
  Future<PlanPage> fetchPlans({
    Object? cursor,
    int limit = AppLimits.plansPageSize,
    List<PlanStatus>? statusFilter,
  }) async {
    try {
      // Soonest-starting plan first — this is the natural "what's next"
      // ordering for both the Plans tab and the Timeline's Upcoming rail.
      Query<Map<String, dynamic>> query = _plansRef.orderBy('startDate');

      if (statusFilter != null && statusFilter.isNotEmpty) {
        // Firestore whereIn supports up to 30 values; PlanStatus has 6.
        query = query.where('status', whereIn: statusFilter.map((s) => s.name).toList());
      }

      if (cursor != null) {
        query = query.startAfterDocument(cursor as DocumentSnapshot<Map<String, dynamic>>);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final items = snapshot.docs.map((d) => Plan.fromFirestore(d.id, d.data())).toList();

      return PlanPage(
        items: items,
        hasMore: snapshot.docs.length == limit,
        cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Stream<Plan?> watchPlan(String planId) {
    return _plansRef.doc(planId).snapshots().map(
          (snap) => snap.exists ? Plan.fromFirestore(snap.id, snap.data()!) : null,
        );
  }

  @override
  Future<List<Plan>> fetchPlansForYear(int year) async {
    try {
      final start = Timestamp.fromDate(DateTime(year, 1, 1));
      final end = Timestamp.fromDate(DateTime(year + 1, 1, 1));
      final snapshot = await _plansRef
          .where('startDate', isGreaterThanOrEqualTo: start)
          .where('startDate', isLessThan: end)
          .get();
      return snapshot.docs.map((d) => Plan.fromFirestore(d.id, d.data())).toList();
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<Plan> createPlan(Plan plan) async {
    try {
      final data = plan.toFirestore()..['createdAt'] = FieldValue.serverTimestamp();

      final DocumentReference<Map<String, dynamic>> docRef;
      if (plan.id.isNotEmpty) {
        docRef = _plansRef.doc(plan.id);
        await docRef.set(data);
      } else {
        docRef = await _plansRef.add(data);
      }

      final snap = await docRef.get();
      return Plan.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> updatePlan(Plan plan) async {
    try {
      await _plansRef.doc(plan.id).update(plan.toFirestore());
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> deletePlan(String planId) async {
    try {
      await _plansRef.doc(planId).delete();
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> updateChecklistItem({
    required String planId,
    required String itemId,
    required bool isDone,
  }) async {
    try {
      final docRef = _plansRef.doc(planId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          throw const NotFoundException('This plan no longer exists.');
        }
        final data = snap.data()!;
        final checklist = (data['checklist'] as List? ?? const [])
            .map((i) => ChecklistItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList();

        final index = checklist.indexWhere((i) => i.id == itemId);
        if (index == -1) {
          throw const NotFoundException('That checklist item no longer exists.');
        }
        checklist[index] = checklist[index].copyWith(isDone: isDone);

        tx.update(docRef, {
          'checklist': checklist.map((c) => c.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }

  @override
  Future<void> updateStatus({required String planId, required PlanStatus status}) async {
    try {
      await _plansRef.doc(planId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
