import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/account_models.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/repositories/provider_portal_repository.dart';

/// The signed-in provider's own business (any status), or null before
/// onboarding.
final myBusinessProvider = FutureProvider<SawaProvider?>((ref) async {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null || !user.isProvider) return null;
  return ref.watch(providerPortalRepositoryProvider).fetchMyProvider(user.id);
});

final myBusinessPrivateProvider = FutureProvider.autoDispose<ProviderPrivate?>((ref) async {
  final b = await ref.watch(myBusinessProvider.future);
  if (b == null) return null;
  return ref.watch(providerPortalRepositoryProvider).fetchPrivate(b.id);
});

/// Real numbers from `get_provider_stats` — never estimated.
final myStatsProvider = FutureProvider.autoDispose<ProviderStats?>((ref) async {
  final b = await ref.watch(myBusinessProvider.future);
  if (b == null) return null;
  return ref.watch(providerPortalRepositoryProvider).fetchStats(b.id);
});

final forwardedRequestsProvider = FutureProvider.autoDispose<List<ContactRequestRecord>>((ref) async {
  final b = await ref.watch(myBusinessProvider.future);
  if (b == null) return const [];
  return ref.watch(providerPortalRepositoryProvider).fetchForwardedRequests(b.id);
});

/// Profile completeness checklist — derived from real fields only.
class CompletenessItem {
  const CompletenessItem(this.label, this.done);
  final String label;
  final bool done;
}

List<CompletenessItem> completeness(SawaProvider b) => [
      const CompletenessItem('اسم النشاط والفئة', true),
      CompletenessItem('وصف واضح', (b.description ?? b.shortDescription) != null),
      CompletenessItem('المنطقة', b.area != null),
      CompletenessItem('صورة غلاف', b.cardImageUrl != null),
      CompletenessItem('صورتان على الأقل', b.galleryImages.length >= 2),
      CompletenessItem('خدمة واحدة على الأقل', b.services.isNotEmpty),
      CompletenessItem('باقة أو سعر', b.packages.isNotEmpty || b.priceFrom != null),
    ];

/// Minimum for submitting to SAWA review.
bool readyForReview(SawaProvider b) =>
    (b.description ?? b.shortDescription) != null && b.area != null && b.services.isNotEmpty;
