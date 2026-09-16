import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../people/domain/entities/person.dart';
import '../../../people/presentation/providers/person_providers.dart';
import '../../domain/entities/plan.dart';
import 'plan_providers.dart';

/// Live single-Plan stream, keyed by ID. Checklist toggles, Edit, Cancel,
/// and Notes/Budget edits all reflect here instantly without any manual
/// refresh/invalidate wiring.
final planDetailProvider = StreamProvider.autoDispose.family<Plan?, String>((ref, planId) {
  return ref.watch(planRepositoryProvider).watchPlan(planId);
});

/// Resolves a Plan's `peopleIds` against the user's full People list, the
/// same approach used by Moment Detail.
final planPeopleProvider = Provider.autoDispose.family<List<Person>, Plan>((ref, plan) {
  final all = ref.watch(peopleListProvider).valueOrNull ?? const <Person>[];
  if (plan.peopleIds.isEmpty) return const [];
  final ids = plan.peopleIds.toSet();
  return all.where((p) => ids.contains(p.id)).toList();
});
