enum InviteStatus { pending, accepted }

/// An invitation for [email] to join [householdId]. Matched against the
/// signed-in user's own email client-side — see
/// `HouseholdRepository.watchPendingInvitesForEmail`.
class HouseholdInvite {
  const HouseholdInvite({
    required this.id,
    required this.householdId,
    required this.email,
    required this.invitedByUid,
    required this.status,
  });

  final String id;
  final String householdId;
  final String email;
  final String invitedByUid;
  final InviteStatus status;

  factory HouseholdInvite.fromFirestore(
    String id,
    String householdId,
    Map<String, dynamic> data,
  ) {
    return HouseholdInvite(
      id: id,
      householdId: householdId,
      email: (data['email'] as String).toLowerCase(),
      invitedByUid: data['invitedByUid'] as String,
      status: InviteStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => InviteStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email.toLowerCase(),
        'invitedByUid': invitedByUid,
        'status': status.name,
      };
}
