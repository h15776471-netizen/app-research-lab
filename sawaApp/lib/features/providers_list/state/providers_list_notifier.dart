import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_fixture_flag.dart';
import '../data/provider_category.dart';
import '../data/provider_model.dart';
import '../data/providers_repository.dart';

/// NOTE: this file holds Phase 1 data-loading providers plus the
/// providerByIdProvider used by ProviderDetailsScreen.
/// The category free-text search / filter Notifier is a Should-Have on
/// the cut-first list and is not included in the hackathon MVP.

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

/// Providers filtered to a single category. CategoryScreen reads this.
final providersByCategoryProvider =
    FutureProvider.family<List<SawaProvider>, ProviderCategory>(
        (ref, category) async {
  final all = await ref.watch(allProvidersProvider.future);
  return all.where((p) => p.category == category).toList(growable: false);
});

/// Looks up a single provider by [id]. Returns null when the id is not in
/// the dataset (unknown route, stale deep link, etc.) so callers can show a
/// graceful "not found" state instead of throwing.
final providerByIdProvider =
    FutureProvider.family<SawaProvider?, String>((ref, id) async {
  final all = await ref.watch(allProvidersProvider.future);
  final index = all.indexWhere((p) => p.id == id);
  return index >= 0 ? all[index] : null;
});
