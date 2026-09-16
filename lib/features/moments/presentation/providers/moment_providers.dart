import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../household/presentation/providers/household_providers.dart';
import '../../data/repositories/firestore_moment_repository.dart';
import '../../domain/repositories/moment_repository.dart';

final momentRepositoryProvider = Provider<MomentRepository>((ref) {
  final householdId = ref.watch(householdIdProvider).valueOrNull;
  if (householdId == null) {
    throw StateError('momentRepositoryProvider read before householdId is known.');
  }
  return FirestoreMomentRepository(householdId: householdId);
});
