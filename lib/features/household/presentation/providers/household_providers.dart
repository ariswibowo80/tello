import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_household_repository.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_invite.dart';
import '../../domain/repositories/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return FirestoreHouseholdRepository();
});

/// Streams the signed-in user's `householdId` from `users/{uid}`. This is
/// the join point between auth and all household-scoped data (plans,
/// moments) — GoRouter's splash gate waits on this the same way it waits
/// on the initial auth state, so no screen ever builds before it's known.
final householdIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  final repo = ref.watch(householdRepositoryProvider);
  return repo.watchOrCreateHouseholdId(uid: user.id, email: user.email);
});

/// The signed-in user's full household document (members, owner, etc).
final householdProvider = StreamProvider<Household?>((ref) {
  final householdId = ref.watch(householdIdProvider).valueOrNull;
  if (householdId == null) return Stream.value(null);
  final repo = ref.watch(householdRepositoryProvider);
  return repo.watchHousehold(householdId);
});

/// Pending invites addressed to the signed-in user's email — surfaced as
/// a prompt so they can join a partner's household.
final pendingInvitesProvider = StreamProvider<List<HouseholdInvite>>((ref) {
  final email = ref.watch(currentUserProvider)?.email;
  if (email == null || email.isEmpty) return Stream.value(const []);
  final repo = ref.watch(householdRepositoryProvider);
  return repo.watchPendingInvitesForEmail(email);
});
