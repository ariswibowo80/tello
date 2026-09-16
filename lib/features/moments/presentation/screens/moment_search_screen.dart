import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/entities/moment.dart';
import '../providers/moment_search_providers.dart';
import '../widgets/moment_card.dart';

/// Case-insensitive substring match against everything worth searching
/// on a Moment: title, description, notes, location name/address, tags.
bool _matches(Moment moment, String query) {
  final q = query.toLowerCase();
  if (moment.title.toLowerCase().contains(q)) return true;
  if (moment.description?.toLowerCase().contains(q) == true) return true;
  if (moment.notes?.toLowerCase().contains(q) == true) return true;
  if (moment.location?.name.toLowerCase().contains(q) == true) return true;
  if (moment.location?.address?.toLowerCase().contains(q) == true) return true;
  if (moment.tags.any((t) => t.toLowerCase().contains(q))) return true;
  return false;
}

class MomentSearchScreen extends ConsumerStatefulWidget {
  const MomentSearchScreen({super.key});

  @override
  ConsumerState<MomentSearchScreen> createState() => _MomentSearchScreenState();
}

class _MomentSearchScreenState extends ConsumerState<MomentSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indexAsync = ref.watch(momentSearchIndexProvider);
    final trimmedQuery = _query.trim();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search moments...',
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: indexAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(momentSearchIndexProvider),
        ),
        data: (moments) {
          if (trimmedQuery.isEmpty) {
            return const _SearchHint();
          }
          final results = moments.where((m) => _matches(m, trimmedQuery)).toList();
          if (results.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No moments found',
              message: 'Try a different word - a title, place, or tag.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: results.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MomentCard(
                moment: results[i],
                onTap: () => context.push('/moment/${results[i].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Search by title, place, or tag',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
