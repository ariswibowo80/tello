import 'package:tello/features/moments/domain/entities/moment.dart';
import 'package:tello/features/moments/domain/repositories/moment_repository.dart';

/// In-memory [MomentRepository] for widget tests — no Firebase involved.
/// Mirrors the real Firestore implementation's behavior closely enough
/// for UI tests (filtering, sorting, pagination via a single page),
/// without needing an emulator or mocking the Firestore SDK.
class FakeMomentRepository implements MomentRepository {
  FakeMomentRepository({List<Moment> initial = const []}) : _moments = List.of(initial);

  final List<Moment> _moments;
  int _idCounter = 0;

  @override
  String newMomentId() => 'fake-moment-${_idCounter++}';

  @override
  Future<MomentPage> fetchMoments({
    Object? cursor,
    int limit = 20,
    bool oldestFirst = false,
    List<String>? tagFilter,
  }) async {
    var items = List<Moment>.from(_moments);
    if (tagFilter != null && tagFilter.isNotEmpty) {
      items = items.where((m) => m.tags.any(tagFilter.contains)).toList();
    }
    items.sort((a, b) =>
        oldestFirst ? a.startDate.compareTo(b.startDate) : b.startDate.compareTo(a.startDate));
    return MomentPage(items: items.take(limit).toList(), hasMore: false);
  }

  @override
  Stream<Moment?> watchMoment(String momentId) {
    final match = _moments.where((m) => m.id == momentId);
    return Stream.value(match.isEmpty ? null : match.first);
  }

  @override
  Future<List<Moment>> fetchMomentsForYear(int year) async {
    return _moments.where((m) => m.startDate.year == year).toList();
  }

  @override
  Future<List<Moment>> fetchMomentsOnThisDay(String monthDay) async {
    return _moments.where((m) => Moment.monthDayKey(m.startDate) == monthDay).toList();
  }

  @override
  Future<Moment> createMoment(Moment moment) async {
    _moments.removeWhere((m) => m.id == moment.id);
    _moments.add(moment);
    return moment;
  }

  @override
  Future<void> updateMoment(Moment moment) async {
    final index = _moments.indexWhere((m) => m.id == moment.id);
    if (index != -1) _moments[index] = moment;
  }

  @override
  Future<void> deleteMoment(String momentId) async {
    _moments.removeWhere((m) => m.id == momentId);
  }

  @override
  Future<Moment> createMomentFromPlan({required String planId, required Moment draft}) async {
    _moments.add(draft);
    return draft;
  }
}
