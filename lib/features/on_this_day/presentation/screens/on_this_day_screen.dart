import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../moments/presentation/widgets/moment_card.dart';
import '../providers/on_this_day_providers.dart';

class OnThisDayScreen extends ConsumerWidget {
  const OnThisDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(onThisDayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('On This Day')),
      body: momentsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e is AppException ? e.message : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(onThisDayProvider),
        ),
        data: (moments) {
          if (moments.isEmpty) {
            return const EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Nothing from this day yet',
              message: 'As your Timeline grows, memories from this exact day\n'
                  'in past years will show up here.',
            );
          }

          final today = DateTime.now();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: moments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, i) {
              final moment = moments[i];
              final yearsAgo = today.year - moment.startDate.year;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$yearsAgo ${yearsAgo == 1 ? 'year' : 'years'} ago',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MomentCard(
                    moment: moment,
                    onTap: () => context.push('/moment/${moment.id}'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
