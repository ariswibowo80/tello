import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/moment.dart';
import 'moment_providers.dart';

/// All of the household's Moments, fetched once per search session for
/// client-side filtering (see [MomentRepository.fetchAllMomentsForSearch]
/// for why). autoDispose so it's refetched fresh each time Moment Search
/// is opened, rather than going stale across sessions.
final momentSearchIndexProvider = FutureProvider.autoDispose<List<Moment>>((ref) {
  final repository = ref.watch(momentRepositoryProvider);
  return repository.fetchAllMomentsForSearch();
});
