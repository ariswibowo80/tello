import '../entities/person.dart';

abstract class PersonRepository {
  /// The person's full list is expected to stay small (family/friends),
  /// so a single live stream — not pagination — is the right shape here.
  Stream<List<Person>> watchPeople();

  Future<Person> createPerson({required String name, String? relationship});
}
