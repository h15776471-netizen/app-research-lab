import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'provider_category.dart';
import 'provider_model.dart';

/// Reads the local, team-managed provider dataset.
///
/// Read-only, always — provider data is never created/updated/deleted from
/// the app (sawa-product-specification.md: "Providers not users").
///
/// Data pipeline: Instagram (manual) → Google Sheet → CSV →
/// assets/data/providers.json → this repository → UI
/// (Technical Architecture §7).
class ProvidersRepository {
  ProvidersRepository({
    this.assetPath = defaultAssetPath,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  /// The real, shipped dataset path. Starts as an empty JSON array (`[]`)
  /// until the team's real 10–20-per-category providers are ready — see
  /// assets/data/providers.json. Never point this at the dev fixture file
  /// outside of [kUseDevFixtureProviders] (see providers_list_notifier.dart).
  static const defaultAssetPath = 'assets/data/providers.json';

  /// Clearly-isolated development fixture — never the default, never
  /// shipped as real data. See lib/core/dev/dev_fixture_flag.dart.
  static const devFixtureAssetPath = 'assets/data/dev_fixture_providers.json';

  final String assetPath;
  final AssetBundle _bundle;

  Future<List<SawaProvider>> getAll() async {
    final raw = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      debugPrint(
        'ProvidersRepository: "$assetPath" did not contain a JSON array at '
        'the top level — returning an empty provider list instead of '
        'crashing.',
      );
      return const [];
    }

    final providers = <SawaProvider>[];
    final seenIds = <String>{};

    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        debugPrint('ProvidersRepository: skipped a non-object record.');
        continue;
      }

      try {
        final provider = SawaProvider.fromJson(entry);

        // A duplicate provider id is a data problem to flag back to the
        // team, not something to silently "fix" by guessing which copy is
        // correct (Skill Module 5).
        if (!seenIds.add(provider.id)) {
          debugPrint(
            'ProvidersRepository: duplicate provider id "${provider.id}" — '
            'flag this back to the data team. Keeping only the first '
            'occurrence.',
          );
          continue;
        }

        providers.add(provider);
      } on FormatException catch (e) {
        // Malformed individual record: skipped and logged, never silently
        // dropped without a trace, never "repaired" with guessed values.
        debugPrint('ProvidersRepository: skipped a malformed record — $e');
      }
    }

    return providers;
  }

  Future<List<SawaProvider>> getByCategory(ProviderCategory category) async {
    final all = await getAll();
    return all.where((p) => p.category == category).toList(growable: false);
  }
}
