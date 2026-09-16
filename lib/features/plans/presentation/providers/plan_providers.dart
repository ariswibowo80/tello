import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../household/presentation/providers/household_providers.dart';
import '../../data/repositories/firestore_plan_repository.dart';
import '../../domain/repositories/plan_repository.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final householdId = ref.watch(householdIdProvider).valueOrNull;
  if (householdId == null) {
    throw StateError('planRepositoryProvider read before householdId is known.');
  }
  return FirestorePlanRepository(householdId: householdId);
});
