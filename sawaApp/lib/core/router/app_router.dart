import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/contact_request/presentation/contact_request_screen.dart';
import '../../features/contact_request/presentation/contact_success_screen.dart';
import '../../features/customer/event_planner/presentation/event_planner_screen.dart';
import '../../features/customer/home/presentation/customer_home_screen.dart';
import '../../features/customer/profile/presentation/customer_profile_screen.dart';
import '../../features/customer/requests/presentation/my_requests_screen.dart';
import '../../features/customer/shell/customer_shell.dart';
import '../../features/provider/dashboard/presentation/provider_dashboard_screen.dart';
import '../../features/provider/onboarding/presentation/provider_onboarding_screen.dart';
import '../../features/provider/profile/presentation/provider_profile_screen.dart';
import '../../features/provider/requests/presentation/provider_requests_screen.dart';
import '../../features/provider/services/presentation/add_edit_service_screen.dart';
import '../../features/provider/services/presentation/provider_services_screen.dart';
import '../../features/provider/shell/provider_shell.dart';
import '../../features/provider_details/presentation/provider_details_screen.dart';
import '../../features/providers_list/data/provider_category.dart';
import '../../features/providers_list/presentation/category_screen.dart';
import '../../features/providers_list/presentation/explore_screen.dart';

abstract final class AppRoute {
  // Auth
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const login = 'login';
  static const signup = 'signup';

  // Customer shell tabs
  static const customerHome = 'customerHome';
  static const explore = 'explore';
  static const myRequests = 'myRequests';
  static const customerProfile = 'customerProfile';

  // Customer full-screen
  static const category = 'category';
  static const providerDetails = 'providerDetails';
  static const contactRequest = 'contactRequest';
  static const contactSuccess = 'contactSuccess';
  static const eventPlanner = 'eventPlanner';

  // Provider shell tabs
  static const providerDashboard = 'providerDashboard';
  static const providerServices = 'providerServices';
  static const providerRequests = 'providerRequests';
  static const providerProfile = 'providerProfile';

  // Provider full-screen
  static const providerOnboarding = 'providerOnboarding';
  static const addService = 'addService';
  static const editService = 'editService';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loading = authState.isLoading;
      final authenticated = authState.isAuthenticated;
      final isProvider = authState.isProvider;
      final path = state.uri.path;

      if (loading && path != '/splash') return '/splash';

      if (!loading) {
        if (path == '/splash') {
          return authenticated ? (isProvider ? '/p/dashboard' : '/c/home') : '/welcome';
        }
        if (authenticated) {
          if (['/welcome', '/login', '/signup'].contains(path)) {
            return isProvider ? '/p/dashboard' : '/c/home';
          }
          if (isProvider && path.startsWith('/c/')) {
            return '/p/dashboard';
          }
          if (!isProvider && path.startsWith('/p/')) {
            return '/c/home';
          }
        }
        if (!authenticated && path.startsWith('/p/')) {
          return '/welcome';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: AppRoute.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        name: AppRoute.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: AppRoute.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: AppRoute.signup,
        builder: (_, __) => const SignupScreen(),
      ),

      // ── Customer shell (bottom nav) ───────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: '/c/home',
            name: AppRoute.customerHome,
            builder: (_, __) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: '/c/explore',
            name: AppRoute.explore,
            builder: (_, __) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/c/requests',
            name: AppRoute.myRequests,
            builder: (_, __) => const MyRequestsScreen(),
          ),
          GoRoute(
            path: '/c/profile',
            name: AppRoute.customerProfile,
            builder: (_, __) => const CustomerProfileScreen(),
          ),
        ],
      ),

      // ── Customer full-screen (no bottom nav) ─────────────────────────
      GoRoute(
        path: '/c/category/:categoryId',
        name: AppRoute.category,
        builder: (_, state) => CategoryScreen(
          category: ProviderCategory.fromId(
            state.pathParameters['categoryId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/c/provider/:providerId',
        name: AppRoute.providerDetails,
        builder: (_, state) => ProviderDetailsScreen(
          providerId: state.pathParameters['providerId']!,
        ),
      ),
      GoRoute(
        path: '/c/contact/:providerId',
        name: AppRoute.contactRequest,
        builder: (_, state) => ContactRequestScreen(
          providerId: state.pathParameters['providerId']!,
        ),
      ),
      GoRoute(
        path: '/c/contact-success',
        name: AppRoute.contactSuccess,
        builder: (_, __) => const ContactSuccessScreen(),
      ),
      GoRoute(
        path: '/c/event-planner',
        name: AppRoute.eventPlanner,
        builder: (_, __) => const EventPlannerScreen(),
      ),

      // ── Provider shell (bottom nav) ───────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => ProviderShell(child: child),
        routes: [
          GoRoute(
            path: '/p/dashboard',
            name: AppRoute.providerDashboard,
            builder: (_, __) => const ProviderDashboardScreen(),
          ),
          GoRoute(
            path: '/p/services',
            name: AppRoute.providerServices,
            builder: (_, __) => const ProviderServicesScreen(),
          ),
          GoRoute(
            path: '/p/requests',
            name: AppRoute.providerRequests,
            builder: (_, __) => const ProviderRequestsScreen(),
          ),
          GoRoute(
            path: '/p/profile',
            name: AppRoute.providerProfile,
            builder: (_, __) => const ProviderProfileScreen(),
          ),
        ],
      ),

      // ── Provider full-screen ──────────────────────────────────────────
      GoRoute(
        path: '/p/onboarding',
        name: AppRoute.providerOnboarding,
        builder: (_, __) => const ProviderOnboardingScreen(),
      ),
      GoRoute(
        path: '/p/service/new',
        name: AppRoute.addService,
        builder: (_, __) => const AddEditServiceScreen(),
      ),
      GoRoute(
        path: '/p/service/:id/edit',
        name: AppRoute.editService,
        builder: (_, state) => AddEditServiceScreen(
          serviceId: state.pathParameters['id'],
        ),
      ),
    ],
  );
});

// Allows GoRouter to react to auth state changes
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}
