// Live check of the app's own data layer against a real Supabase project.
// Skipped unless both values are passed at run time (never stored in the repo):
//
//   flutter test test/live --dart-define=SUPABASE_URL=https://<id>.supabase.co \
//                          --dart-define=SUPABASE_ANON_KEY=<publishable key>
//
// Read-only: uses only the publishable key and SELECT queries.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/data/models/catalog_models.dart';
import 'package:sawa/data/repositories/catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  final skip = (_url.isEmpty || _key.isEmpty) ? 'SUPABASE_URL / SUPABASE_ANON_KEY not provided' : null;
  if (_key.startsWith('sb_secret_') || _key.contains('service_role')) {
    throw StateError('Refusing to run with a secret key — use the publishable key.');
  }

  late SupabaseClient client;
  late SupabaseCatalogRepository repo;
  setUpAll(() {
    if (skip != null) return;
    client = SupabaseClient(_url, _key);
    repo = SupabaseCatalogRepository(client);
  });

  test('categories come from Supabase', () async {
    final cats = await repo.fetchCategories();
    expect(cats.map((c) => c.id), containsAll(['halls', 'photography', 'flowers']));
    expect(cats, hasLength(10));
  }, skip: skip);

  test('the 15 published providers come from Supabase and match the bundled catalog', () async {
    final live = await repo.fetchProviders();
    expect(live, hasLength(15));
    expect(live.every((p) => p.status == ListingStatus.published), isTrue);

    final bundled = jsonDecode(File('assets/data/catalog.json').readAsStringSync()) as Map<String, dynamic>;
    final bundledIds = (bundled['providers'] as List).map((p) => (p as Map)['id']).toSet();
    expect(live.map((p) => p.id).toSet(), bundledIds, reason: 'seed and bundled catalog share deterministic ids');

    final ritaj = live.firstWhere((p) => p.legacyId == 'hall_ritaj_001');
    expect(ritaj.lowestOffer(DateTime(2026, 9, 25))!.from, 500000);
    expect(ritaj.basePrice(DateTime(2026, 9, 25)), isNull);
    final malika = live.firstWhere((p) => p.legacyId == 'hall_malika_001');
    expect(malika.images, isNotEmpty);
    expect(malika.fieldSources, isNotEmpty);
    expect(live.firstWhere((p) => p.legacyId == 'decor_ward_001').instagramUrl, isNull);
  }, skip: skip);

  test('lookup by legacy id and draft listings stay hidden', () async {
    expect((await repo.fetchProvider('hall_jadriya_001'))!.capacity, 200);
    expect(await repo.fetchProvider('hall_almas_001'), isNull);
  }, skip: skip);

  test('private tables are not readable with the public key', () async {
    for (final t in ['provider_private', 'contact_requests', 'profiles']) {
      Object? error;
      List<dynamic>? rows;
      try {
        rows = await client.from(t).select().limit(1);
      } catch (e) {
        error = e;
      }
      expect(error != null || (rows?.isEmpty ?? false), isTrue, reason: '$t leaked to anon');
    }
  }, skip: skip);
}
