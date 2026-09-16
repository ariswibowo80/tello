import '../entities/household.dart';
import '../entities/household_invite.dart';

abstract class HouseholdRepository {
  Stream<Household?> watchHousehold(String householdId);

  /// Streams the signed-in user's `householdId`, auto-creating a
  /// household of one if they don't have one yet — e.g. an account whose
  /// session predates household support, or was restored automatically
  /// without going through sign-in (which is the only place a fresh
  /// account normally gets one).
  Stream<String?> watchOrCreateHouseholdId({required String uid, String? email});

  /// Invites [email] to join [householdId]. Does not send an actual
  /// email — the invitee sees this as an in-app prompt the next time
  /// they're signed in with a matching email (see
  /// [watchPendingInvitesForEmail]).
  Future<void> sendInvite({
    required String householdId,
    required String email,
    required String invitedByUid,
  });

  /// Pending invites addressed to [email], across all households.
  Stream<List<HouseholdInvite>> watchPendingInvitesForEmail(String email);

  /// Adds [uid] to [invite]'s household and repoints `users/{uid}.householdId`
  /// at it. The user's previous household (and any data under it) is left
  /// untouched but no longer reachable from their account.
  Future<void> acceptInvite({
    required HouseholdInvite invite,
    required String uid,
  });

  /// Removes [memberUid] (whose email in this household is [memberEmail])
  /// from [householdId], and clears their `users/{uid}.householdId` so
  /// they get a fresh household of their own next time the app checks
  /// (see [watchOrCreateHouseholdId]). Used both for a member leaving on
  /// their own and for the owner removing someone else.
  Future<void> removeMember({
    required String householdId,
    required String memberUid,
    required String memberEmail,
  });
}
