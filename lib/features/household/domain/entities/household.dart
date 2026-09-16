/// A shared space plans and moments live in — typically a couple or
/// family. Every user belongs to exactly one household at a time
/// (`users/{uid}.householdId`), starting as the sole member of their own
/// on sign-up, and can later join someone else's via an accepted invite.
class Household {
  const Household({
    required this.id,
    required this.ownerUid,
    required this.members,
    required this.memberEmails,
  });

  final String id;
  final String ownerUid;
  final List<String> members;
  final List<String> memberEmails;

  factory Household.fromFirestore(String id, Map<String, dynamic> data) {
    return Household(
      id: id,
      ownerUid: data['ownerUid'] as String,
      members: List<String>.from(data['members'] as List? ?? const []),
      memberEmails: List<String>.from(data['memberEmails'] as List? ?? const []),
    );
  }
}
