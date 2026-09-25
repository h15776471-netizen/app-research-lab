import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
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
import '../../features/provider/services/presentation/add_edit_package_screen.dart';
import '../../features/provider/services/presentation/add_edit_service_screen.dart';
import '../../features/provider/services/presentation/provider_services_screen.dart';
import '../../features/provider/shell/provider_shell.dart';
import '../../features/provider_details/presentation/provider_details_screen.dart';
import '../../features/providers_list/presentation/category_screen.dart';
import '../../features/providers_list/presentation/explore_screen.dart';
import '../auth/auth_notifier.dart';

abstract final class AppRoute {
  // Auth
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const login = 'login';
  static const signup = 'signup';
  static const forgotPassword = 'forgotPassword';

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
  static const addPackage = 'addPackage';
  static const editPackage = 'editPackage';
}

const _authPaths = {'/welcome', '/login', '/signup', '/forgot-password'};

/// Pure redirect rules (unit-tested). Role checks here only shape
/// navigation; the database enforces every permission.
String? resolveRedirect({required String path, required AuthState auth}) {
  // While the session restores, stay put; the router re-runs when it settles.
  if (auth.isLoading) return null;
  final home = auth.isProvider ? '/p/dashboard' : '/c/home';
  if (path == '/splash' || path == '/') {
    return auth.isAuthenticated ? home : '/welcome';
  }
  if (auth.isAuthenticated && _authPaths.contains(path)) return home;
  if (path.startsWith('/p/')) {
    if (!auth.isAuthenticated) return '/login';
    if (!auth.isProvider) return '/c/home';
  }
  if (path.startsWith('/c/') && auth.isProvider) return '/p/dashboard';
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(path: state.uri.path, auth: ref.read(authNotifierProvider)),
    errorBuilder: (_, __) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/splash'),
      GoRoute(path: '/splash', name: AppRoute.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', name: AppRoute.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/login',
        name: AppRoute.login,
        builder: (_, s) => LoginScreen(returnTo: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/signup',
        name: AppRoute.signup,
        builder: (_, s) => SignupScreen(initialProvider: s.uri.queryParameters['role'] == 'provider'),
      ),
      GoRoute(
        path: '/forgot-password',
        name: AppRoute.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ── Customer shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => CustomerShell(child: child),
        routes: [
          GoRoute(path: '/c/home', name: AppRoute.customerHome, builder: (_, __) => const CustomerHomeScreen()),
          GoRoute(
            path: '/c/explore',
            name: AppRoute.explore,
            builder: (_, s) => ExploreScreen(initialQuery: s.uri.queryParameters['q']),
          ),
          GoRoute(path: '/c/requests', name: AppRoute.myRequests, builder: (_, __) => const MyRequestsScreen()),
          GoRoute(
              path: '/c/profile', name: AppRoute.customerProfile, builder: (_, __) => const CustomerProfileScreen()),
        ],
      ),

      // ── Customer full-screen ─────────────────────────────────────────
      GoRoute(
        path: '/c/category/:categoryId',
        name: AppRoute.category,
        builder: (_, s) => CategoryScreen(categoryId: s.pathParameters['categoryId']!),
      ),
      GoRoute(
        path: '/c/provider/:providerId',
        name: AppRoute.providerDetails,
        builder: (_, s) => ProviderDetailsScreen(providerId: s.pathParameters['providerId']!),
      ),
      GoRoute(
        path: '/c/contact/:providerId',
        name: AppRoute.contactRequest,
        builder: (_, s) => ContactRequestScreen(
          providerId: s.pathParameters['providerId']!,
          serviceId: s.uri.queryParameters['service'],
          packageTitle: s.uri.queryParameters['package'],
        ),
      ),
      GoRoute(
        path: '/c/contact-success',
        name: AppRoute.contactSuccess,
        builder: (_, s) => ContactSuccessScreen(
          reference: s.uri.queryParameters['ref'],
          kind: s.uri.queryParameters['kind'] ?? 'contact',
        ),
      ),
      GoRoute(path: '/c/planner', name: AppRoute.eventPlanner, builder: (_, __) => const EventPlannerScreen()),

      // ── Provider shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => ProviderShell(child: child),
        routes: [
          GoRoute(
              path: '/p/dashboard',
              name: AppRoute.providerDashboard,
              builder: (_, __) => const ProviderDashboardScreen()),
          GoRoute(
              path: '/p/services', name: AppRoute.providerServices, builder: (_, __) => const ProviderServicesScreen()),
          GoRoute(
              path: '/p/requests', name: AppRoute.providerRequests, builder: (_, __) => const ProviderRequestsScreen()),
          GoRoute(
              path: '/p/profile', name: AppRoute.providerProfile, builder: (_, __) => const ProviderProfileScreen()),
        ],
      ),

      // ── Provider full-screen ──────────────────────────────────────────
      GoRoute(
          path: '/p/onboarding',
          name: AppRoute.providerOnboarding,
          builder: (_, __) => const ProviderOnboardingScreen()),
      GoRoute(path: '/p/service/new', name: AppRoute.addService, builder: (_, __) => const AddEditServiceScreen()),
      GoRoute(
        path: '/p/service/:id/edit',
        name: AppRoute.editService,
        builder: (_, s) => AddEditServiceScreen(serviceId: s.pathParameters['id']),
      ),
      GoRoute(path: '/p/package/new', name: AppRoute.addPackage, builder: (_, __) => const AddEditPackageScreen()),
      GoRoute(
        path: '/p/package/:id/edit',
        name: AppRoute.editPackage,
        builder: (_, s) => AddEditPackageScreen(packageId: s.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (prev?.user?.id != next.user?.id || prev?.user?.role != next.user?.role || prev?.isLoading != next.isLoading) {
        notifyListeners();
      }
    });
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.explore_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('الصفحة غير موجودة'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/c/home'), child: const Text('العودة للرئيسية')),
        ]),
      ),
    );
  }
}
