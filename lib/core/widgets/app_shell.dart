import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/plans/presentation/providers/plans_list_controller.dart';
import '../../features/timeline/presentation/providers/moments_timeline_controller.dart';
import '../../features/timeline/presentation/providers/plans_timeline_controller.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';

/// Wraps the five primary destinations (Timeline, Plans, [Add], Places,
/// Profile) in a persistent bottom navigation bar. The central Add button
/// opens an action sheet rather than navigating directly, per spec.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    AppRoutes.timeline,
    AppRoutes.plans,
    AppRoutes.places,
    AppRoutes.profile,
  ];

  int _indexForLocation(String location) {
    final tabIndex = _tabs.indexWhere((t) => location.startsWith(t));
    return tabIndex == -1 ? 0 : tabIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.timeline_rounded,
              label: 'Timeline',
              isSelected: currentIndex == 0,
              onTap: () => context.go(AppRoutes.timeline),
            ),
            _NavItem(
              icon: Icons.event_note_rounded,
              label: 'Plans',
              isSelected: currentIndex == 1,
              onTap: () => context.go(AppRoutes.plans),
            ),
            const SizedBox(width: 48), // space for the notch/FAB
            _NavItem(
              icon: Icons.place_rounded,
              label: 'Places',
              isSelected: currentIndex == 2,
              onTap: () => context.go(AppRoutes.places),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isSelected: currentIndex == 3,
              onTap: () => context.go(AppRoutes.profile),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What do you want to create?',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.primary,
                  child: Icon(Icons.auto_awesome_rounded),
                ),
                title: const Text('Moment'),
                subtitle: const Text('Record something that happened.'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final created = await context.push<bool>(AppRoutes.addMoment);
                  if (created == true) {
                    // The Moment was written with a fresh doc ID and won't
                    // be in any already-fetched page, so the cleanest fix
                    // is to drop cached pages/cursors and refetch.
                    ref.invalidate(momentsTimelineProvider);
                    ref.invalidate(upcomingPlansProvider);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.planAccentLight,
                  foregroundColor: AppColors.planAccent,
                  child: Icon(Icons.flight_takeoff_rounded),
                ),
                title: const Text('Plan'),
                subtitle: const Text('Plan something that will happen.'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final created = await context.push<bool>(AppRoutes.addPlan);
                  if (created == true) {
                    ref.invalidate(plansListProvider);
                    ref.invalidate(plansTimelineProvider);
                    ref.invalidate(upcomingPlansProvider);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
