import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import 'models/catalog_models.dart';
import 'repositories/auth_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/provider_portal_repository.dart';
import 'repositories/requests_repository.dart';

/// The Supabase client, or null in offline catalog mode. Tests override it.
final supabaseClientProvider = Provider<SupabaseClient?>(
  (_) => SupabaseConfig.isInitialized ? Supabase.instance.client : null,
);

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? LocalCatalogRepository() : SupabaseCatalogRepository(client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseClientProvider)));

final requestsRepositoryProvider =
    Provider<RequestsRepository>((ref) => RequestsRepository(ref.watch(supabaseClientProvider)));

final providerPortalRepositoryProvider =
    Provider<ProviderPortalRepository>((ref) => ProviderPortalRepository(ref.watch(supabaseClientProvider)));

// ── Catalogue state (shared by discovery, details and the planner) ─────────
final categoriesProvider =
    FutureProvider<List<SawaCategory>>((ref) => ref.watch(catalogRepositoryProvider).fetchCategories());

final providersProvider =
    FutureProvider<List<SawaProvider>>((ref) => ref.watch(catalogRepositoryProvider).fetchProviders());

final providerByIdProvider = FutureProvider.family<SawaProvider?, String>((ref, id) async {
  final cached = ref.watch(providersProvider).valueOrNull;
  if (cached != null) {
    for (final p in cached) {
      if (p.id == id || p.legacyId == id) return p;
    }
  }
  return ref.watch(catalogRepositoryProvider).fetchProvider(id);
});

/// Number of published providers per category id (for honest empty states).
final categoryCountsProvider = Provider<Map<String, int>>((ref) {
  final list = ref.watch(providersProvider).valueOrNull ?? const [];
  final m = <String, int>{};
  for (final p in list) {
    m[p.categoryId] = (m[p.categoryId] ?? 0) + 1;
  }
  return m;
});
