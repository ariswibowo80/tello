/// Firestore collection & subcollection names.
/// Keeping these centralized avoids typo-driven bugs across repositories.
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String households = 'households';
  static const String invites = 'invites';
  static const String moments = 'moments';
  static const String plans = 'plans';
  static const String people = 'people';
  static const String places = 'places';
  static const String settings = 'settings';
  static const String familyMembers = 'familyMembers';
  static const String familyAssets = 'familyAssets';
  static const String documents = 'documents';
}

/// Firebase Storage path helpers.
class StoragePaths {
  StoragePaths._();

  static String momentMedia(String householdId, String momentId) =>
      'households/$householdId/moments/$momentId';

  static String planMedia(String householdId, String planId) =>
      'households/$householdId/plans/$planId';

  static String profilePhoto(String userId) => 'users/$userId/profile';

  static String familyMemberFiles(String householdId, String memberId) =>
      'households/$householdId/familyMembers/$memberId';

  static String familyAssetFiles(String householdId, String assetId) =>
      'households/$householdId/familyAssets/$assetId';
}

/// Plan lifecycle states.
enum PlanStatus { idea, planning, confirmed, ongoing, completed, cancelled }

/// Plan categories shown in the "Create Plan" flow.
enum PlanCategory {
  vacation,
  birthday,
  celebration,
  roadTrip,
  dinner,
  gathering,
  school,
  graduation,
  workEvent,
  familyEvent,
  personalMilestone,
  other,
}

/// Validation / UX limits enforced client-side (mirrored server-side where
/// it matters, e.g. via Firestore rules or Cloud Functions).
class AppLimits {
  AppLimits._();

  static const int maxTitleLength = 120;
  static const int maxStoryLength = 5000;
  static const int maxNoteLength = 2000;
  static const int maxMediaPerMoment = 30;
  static const int maxMediaPerPlan = 30;
  static const int maxChecklistItems = 100;
  static const int maxItineraryItems = 100;
  static const int momentsPageSize = 20;
  static const int plansPageSize = 20;
  static const int maxDocumentsPerParent = 50;

  /// How many days before a document's expiry date the first local
  /// reminder fires. A second reminder fires [documentExpiryReminderDaysClose]
  /// before, for anything already past the first window when it's added.
  static const int documentExpiryReminderDaysFar = 30;
  static const int documentExpiryReminderDaysClose = 7;
}

class AppTags {
  AppTags._();

  static const List<String> defaultCategories = [
    'Family',
    'Travel',
    'Work',
    'Celebration',
    'School',
    'Personal',
  ];
}
