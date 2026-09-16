import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/person_repository.dart';

class FirestorePersonRepository implements PersonRepository {
  FirestorePersonRepository({
    required String userId,
    FirebaseFirestore? firestore,
  })  : _userId = userId,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String _userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _peopleRef => _firestore
      .collection(FirestoreCollections.users)
      .doc(_userId)
      .collection(FirestoreCollections.people);

  @override
  Stream<List<Person>> watchPeople() {
    return _peopleRef.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Person.fromFirestore(d.id, d.data())).toList(),
        );
  }

  @override
  Future<Person> createPerson({required String name, String? relationship}) async {
    try {
      final docRef = await _peopleRef.add({
        'name': name,
        'photoUrl': null,
        'relationship': relationship,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final snap = await docRef.get();
      return Person.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw mapFirebaseErrorCode(e.code, cause: e);
    }
  }
}
