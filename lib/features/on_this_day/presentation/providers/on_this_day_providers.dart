import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/domain/entities/moment.dart';
import '../../../moments/presentation/providers/moment_providers.dart';

/// Moments that happened on this exact month/day in a past year, newest
/// past-year first. Backed by the indexed `monthDay` query — see
/// `Moment.monthDayKey` and `MomentRepository.fetchMomentsOnThisDay`.
final onThisDayProvider = FutureProvider.autoDispose<List<Moment>>((ref) async {
  final today = DateTime.now();
  final monthDay = Moment.monthDayKey(today);
  final moments = await ref.watch(momentRepositoryProvider).fetchMomentsOnThisDay(monthDay);

  final pastYears = moments.where((m) => m.startDate.year < today.year).toList()
    ..sort((a, b) => b.startDate.year.compareTo(a.startDate.year));
  return pastYears;
});
