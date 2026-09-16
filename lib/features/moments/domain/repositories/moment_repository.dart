import '../entities/moment.dart';

/// Cursor-based page result so the UI can implement infinite scroll
/// without ever loading the full moments collection at once.
class MomentPage {
  const MomentPage({required this.items, required this.hasMore, this.cursor});

  final List<Moment> items;
  final bool hasMore;
  final Object? cursor;
}

abstract class MomentRepository {
  /// Allocates a fresh, unused document ID without writing anything.
  /// Used so media can be uploaded to `users/{uid}/moments/{id}/...`
  /// *before* the Moment document itself is created.
  String newMomentId();

  /// Newest-first by default; pass [cursor] from the previous page for
  /// pagination. [limit] mirrors [AppLimits.momentsPageSize] by default.
  Future<MomentPage> fetchMoments({
    Object? cursor,
    int limit = 20,
    bool oldestFirst = false,
    List<String>? tagFilter,
  });

  Stream<Moment?> watchMoment(String momentId);

  /// If [moment].id is non-empty (typically from [newMomentId]), the
  /// document is written at that exact ID; otherwise Firestore
  /// auto-generates one.
  Future<Moment> createMoment(Moment moment);

  Future<void> updateMoment(Moment moment);

  Future<void> deleteMoment(String momentId);

  /// Moments whose `startDate` falls within [year] — a single-field range
  /// query, so no composite index is needed. Backs Life in Review.
  Future<List<Moment>> fetchMomentsForYear(int year);

  /// Moments from any previous year that fall on today's month/day —
  /// backed by the `monthDay` field written in `Moment.toFirestore()`.
  Future<List<Moment>> fetchMomentsOnThisDay(String monthDay);

  /// Fetches every Moment in the household for client-side search.
  /// Firestore has no full-text search, and household Moment counts are
  /// small enough (personal/family scale, not enterprise scale) that
  /// fetching once and filtering in memory beats standing up a search
  /// service. Newest-first, same ordering as [fetchMoments].
  Future<List<Moment>> fetchAllMomentsForSearch();

  /// Creates a Moment from a completed Plan (Plan → Moment conversion).
  /// Implementations must also set `plan.convertedToMomentId` atomically.
  Future<Moment> createMomentFromPlan({
    required String planId,
    required Moment draft,
  });
}
