import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/household/presentation/providers/household_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/life_review/presentation/screens/life_review_screen.dart';
import '../../features/moments/domain/entities/moment.dart';
import '../../features/moments/presentation/screens/add_moment_screen.dart';
import '../../features/moments/presentation/screens/moment_detail_screen.dart';
import '../../features/moments/presentation/screens/moment_search_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/on_this_day/presentation/screens/on_this_day_screen.dart';
import '../../features/places/presentation/screens/places_screen.dart';
import '../../features/plans/domain/entities/plan.dart';
import '../../features/plans/presentation/screens/create_plan_screen.dart';
import '../../features/plans/presentation/screens/plan_detail_screen.dart';
import '../../features/plans/presentation/screens/plans_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../widgets/app_shell.dart';

/// Shared with `NotificationService` so a notification tap can navigate
/// even when it arrives before any screen's own `BuildContext` exists
/// (background/terminated app launch).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Route paths as constants to avoid magic strings scattered across the app.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const timeline = '/timeline';
  static const plans = '/plans';
  static const places = '/places';
  static const profile = '/profile';
  static const addMoment = '/add-moment';
  static const editMoment = '/edit-moment';
  static const addPlan = '/add-plan';
  static const editPlan = '/edit-plan';
  static const momentDetail = '/moment/:id';
  static const momentSearch = '/moment-search';
  static const planDetail = '/plan/:id';
  static const onThisDay = '/on-this-day';
  static const notificationSettings = '/notification-settings';
  static const lifeReview = '/life-review';
}

/// Shown only for the brief moment before the first auth state is known.
/// Kept as a route (not a root-widget swap) so the app's Navigator tree
/// is never torn down and rebuilt — swapping the whole MaterialApp type
/// mid-flight can corrupt in-flight ink/animation GlobalKeys.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  // Only watched once signed in — see the isLoggedIn guard below. This
  // avoids the household stream ever running for a signed-out user.
  final isLoggedIn = authState.valueOrNull != null;
  final householdIdState = isLoggedIn ? ref.watch(householdIdProvider) : null;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.onboarding;

      // Still resolving the initial auth state — hold on the splash
      // route rather than letting a protected screen build too early.
      if (authState.isLoading) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (isLoggedIn) {
        // Signed in, but `users/{uid}.householdId` hasn't loaded yet —
        // every plan/moment provider depends on it, so hold on splash
        // the same way we hold for auth above.
        final household = householdIdState;
        final householdReady = household != null
            && !household.isLoading
            && household.hasValue
            && household.value != null;
        if (!householdReady) {
          return isSplash ? null : AppRoutes.splash;
        }
        return (isAuthRoute || isSplash) ? AppRoutes.timeline : null;
      } else {
        return isAuthRoute ? null : AppRoutes.login;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // Bottom-nav shell wraps the five primary destinations so state
      // (scroll position, etc.) is preserved across tab switches.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.timeline,
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: AppRoutes.plans,
            builder: (context, state) => const PlansScreen(),
          ),
          GoRoute(
            path: AppRoutes.places,
            builder: (context, state) => const PlacesScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addMoment,
        builder: (context, state) => const AddMomentScreen(),
      ),
      GoRoute(
        path: AppRoutes.editMoment,
        builder: (context, state) => AddMomentScreen(existingMoment: state.extra as Moment?),
      ),
      GoRoute(
        path: AppRoutes.addPlan,
        builder: (context, state) => const CreatePlanScreen(),
      ),
      GoRoute(
        path: AppRoutes.editPlan,
        builder: (context, state) => CreatePlanScreen(existingPlan: state.extra as Plan?),
      ),
      GoRoute(
        path: AppRoutes.momentDetail,
        builder: (context, state) => MomentDetailScreen(momentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.momentSearch,
        builder: (context, state) => const MomentSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.planDetail,
        builder: (context, state) => PlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.onThisDay,
        builder: (context, state) => const OnThisDayScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.lifeReview,
        builder: (context, state) => const LifeReviewScreen(),
      ),
    ],
  );
});
