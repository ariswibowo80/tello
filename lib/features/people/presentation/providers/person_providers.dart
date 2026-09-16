import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_person_repository.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/person_repository.dart';

final personRepositoryProvider = Provider<PersonRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('personRepositoryProvider read while signed out.');
  }
  return FirestorePersonRepository(userId: user.id);
});

final peopleListProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(personRepositoryProvider).watchPeople();
});
