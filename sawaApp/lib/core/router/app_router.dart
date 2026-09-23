import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/contact_request/presentation/contact_request_screen.dart';
import '../../features/contact_request/presentation/contact_success_screen.dart';
import '../../features/provider_details/presentation/provider_details_screen.dart';
import '../../features/providers_list/data/provider_category.dart';
import '../../features/providers_list/presentation/category_screen.dart';
import '../../features/providers_list/presentation/home_screen.dart';

/// Names for the 5 locked SAWA routes. Exactly 5 — a 6th route is
/// OUT OF SCOPE unless SAWA_FINAL_MASTER_SPEC.md explicitly adds one
/// (Skill Module 2, Scope Guardian).
abstract final class AppRoute {
  static const home = 'home';
  static const category = 'category';
  static const providerDetails = 'providerDetails';
  static const contactRequest = 'contactRequest';
  static const contactSuccess = 'contactSuccess';
}

/// Fully linear navigation, default go_router transitions only — no custom
/// screen transitions (first item on the "cut first" list in every source
/// doc). Home → Category → Provider Details → Contact Request →
/// Contact Success.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/category/:categoryId',
        name: AppRoute.category,
        builder: (context, state) {
          final categoryId = state.pathParameters['categoryId']!;
          return CategoryScreen(category: ProviderCategory.fromId(categoryId));
        },
      ),
      GoRoute(
        path: '/provider/:providerId',
        name: AppRoute.providerDetails,
        builder: (context, state) {
          final providerId = state.pathParameters['providerId']!;
          return ProviderDetailsScreen(providerId: providerId);
        },
      ),
      GoRoute(
        path: '/contact/:providerId',
        name: AppRoute.contactRequest,
        builder: (context, state) {
          final providerId = state.pathParameters['providerId']!;
          return ContactRequestScreen(providerId: providerId);
        },
      ),
      GoRoute(
        path: '/contact-success',
        name: AppRoute.contactSuccess,
        builder: (context, state) => const ContactSuccessScreen(),
      ),
    ],
  );
});
