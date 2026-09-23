import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_fixture_flag.dart';
import '../data/provider_category.dart';
import '../data/provider_model.dart';
import '../data/providers_repository.dart';

/// NOTE: this file currently holds only the Phase 1 data-loading
/// foundation (a repository provider + category-filtered FutureProviders).
/// The category free-text search / filter Notifier described in the
/// Technical Architecture is a Should-Have, deferred to a later phase —
/// see the Phase 1 report.

final providersRepositoryProvider = Provider<ProvidersRepository>((ref) {
  return ProvidersRepository(
    assetPath: kUseDevFixtureProviders
        ? ProvidersRepository.devFixtureAssetPath
        : ProvidersRepository.defaultAssetPath,
  );
});

/// The full, unfiltered provider dataset — loaded once, cached by Riverpod.
final allProvidersProvider = FutureProvider<List<SawaProvider>>((ref) {
  final repository = ref.watch(providersRepositoryProvider);
  return repository.getAll();
});

/// Providers filtered to a single category. This is what CategoryScreen
/// reads — Home shows category tiles, not providers (Skill Module 4:
/// Home vs. Category component responsibility).
final providersByCategoryProvider = FutureProvider.family<List<SawaProvider>,
    ProviderCategory>((ref, category) async {
  final all = await ref.watch(allProvidersProvider.future);
  return all.where((p) => p.category == category).toList(growable: false);
});
