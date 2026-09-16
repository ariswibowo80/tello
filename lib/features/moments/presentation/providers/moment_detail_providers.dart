import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../people/domain/entities/person.dart';
import '../../../people/presentation/providers/person_providers.dart';
import '../../domain/entities/moment.dart';
import 'moment_providers.dart';

/// Live single-Moment stream, keyed by ID. Using a stream (not a one-time
/// fetch) means Edit/Add Photo/Notes changes reflect on this screen
/// instantly without any manual refresh/invalidate wiring.
final momentDetailProvider = StreamProvider.autoDispose.family<Moment?, String>((ref, momentId) {
  return ref.watch(momentRepositoryProvider).watchMoment(momentId);
});

/// Resolves a Moment's `peopleIds` against the user's full People list.
/// `peopleListProvider` is a small, already-live stream, so filtering it
/// client-side is simpler and cheaper than N individual document reads.
final momentPeopleProvider = Provider.autoDispose.family<List<Person>, Moment>((ref, moment) {
  final all = ref.watch(peopleListProvider).valueOrNull ?? const <Person>[];
  if (moment.peopleIds.isEmpty) return const [];
  final ids = moment.peopleIds.toSet();
  return all.where((p) => ids.contains(p.id)).toList();
});
