import '../entities/family_member.dart';

abstract class FamilyMemberRepository {
  String newMemberId();
  Stream<List<FamilyMember>> watchMembers();
  Stream<FamilyMember?> watchMember(String memberId);
  Future<FamilyMember> createMember(FamilyMember member);
  Future<void> updateMember(FamilyMember member);
  Future<void> deleteMember(String memberId);
}
