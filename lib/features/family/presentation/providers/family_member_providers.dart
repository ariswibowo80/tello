import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../household/presentation/providers/household_providers.dart';
import '../../data/repositories/firestore_family_member_repository.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/repositories/family_member_repository.dart';

final familyMemberRepositoryProvider = Provider<FamilyMemberRepository>((ref) {
  final householdId = ref.watch(householdIdProvider).valueOrNull;
  if (householdId == null) {
    throw StateError('familyMemberRepositoryProvider read before householdId is known.');
  }
  return FirestoreFamilyMemberRepository(householdId: householdId);
});

final familyMembersListProvider = StreamProvider<List<FamilyMember>>((ref) {
  return ref.watch(familyMemberRepositoryProvider).watchMembers();
});

final familyMemberProvider = StreamProvider.family<FamilyMember?, String>((ref, memberId) {
  return ref.watch(familyMemberRepositoryProvider).watchMember(memberId);
});
