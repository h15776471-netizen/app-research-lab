import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_models.dart';

/// Read access to the public catalogue: categories + published providers
/// with their images, services, packages and per-field provenance.
abstract interface class CatalogRepository {
  /// True when data comes live from Supabase (vs the bundled catalog).
  bool get isLive;
  Future<List<SawaCategory>> fetchCategories();
  Future<List<SawaProvider>> fetchProviders();

  /// Accepts the provider uuid, or a v1 legacy id (old deep links).
  Future<SawaProvider?> fetchProvider(String idOrLegacyId);

  /// Records a real profile view (server de-duplicates; no-op offline).
  Future<void> recordView(String providerId);
}

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

/// PostgREST select that returns exactly the catalog.json provider shape.
const providerSelect = '*, '
    'images:provider_images(*), '
    'services(*), '
    'packages:provider_packages(*), '
    'field_sources:provider_field_sources(field,status,note)';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isLive => true;

  @override
  Future<List<SawaCategory>> fetchCategories() async {
    final data = await _client.from('categories').select().eq('is_active', true).order('sort_order');
    return data.map(SawaCategory.fromJson).toList();
  }

  @override
  Future<List<SawaProvider>> fetchProviders() async {
    final data = await _client
        .from('providers')
        .select(providerSelect)
        .eq('status', 'published')
        .order('published_at', ascending: true);
    return _parse(data);
  }

  @override
  Future<SawaProvider?> fetchProvider(String idOrLegacyId) async {
    final column = _uuid.hasMatch(idOrLegacyId) ? 'id' : 'legacy_id';
    final row = await _client
        .from('providers')
        .select(providerSelect)
        .eq(column, idOrLegacyId)
        .eq('status', 'published')
        .maybeSingle();
    return row == null ? null : SawaProvider.fromJson(row);
  }

  @override
  Future<void> recordView(String providerId) async {
    try {
      await _client.rpc('record_provider_view', params: {'p_provider_id': providerId});
    } catch (e) {
      debugPrint('recordView: $e'); // analytics must never break browsing
    }
  }
}

/// The bundled catalog (`assets/data/catalog.json`), generated from the same
/// reviewed dataset that seeds Supabase — used when Supabase is not
/// configured. Read-only.
class LocalCatalogRepository implements CatalogRepository {
  LocalCatalogRepository({AssetBundle? bundle, this.assetPath = defaultAsset}) : _bundle = bundle ?? rootBundle;

  static const defaultAsset = 'assets/data/catalog.json';

  final AssetBundle _bundle;
  final String assetPath;
  Map<String, dynamic>? _cache;

  @override
  bool get isLive => false;

  // Decoded from bytes directly: loadString() moves strings > 50 KB to a
  // background isolate, which is unnecessary here (~100 KB) and never
  // completes under widget-test fake time.
  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    final data = await _bundle.load(assetPath);
    final text = utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return _cache = jsonDecode(text) as Map<String, dynamic>;
  }

  @override
  Future<List<SawaCategory>> fetchCategories() async {
    final j = await _load();
    final list = (j['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((c) => c['is_active'] != false)
        .map(SawaCategory.fromJson)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<List<SawaProvider>> fetchProviders() async {
    final j = await _load();
    return _parse((j['providers'] as List? ?? const []).whereType<Map<String, dynamic>>().toList())
        .where((p) => p.status == ListingStatus.published)
        .toList();
  }

  @override
  Future<SawaProvider?> fetchProvider(String idOrLegacyId) async {
    for (final p in await fetchProviders()) {
      if (p.id == idOrLegacyId || p.legacyId == idOrLegacyId) return p;
    }
    return null;
  }

  @override
  Future<void> recordView(String providerId) async {}
}

/// Malformed rows are skipped and logged — never repaired with guesses.
List<SawaProvider> _parse(List<Map<String, dynamic>> data) {
  final out = <SawaProvider>[];
  final seen = <String>{};
  for (final row in data) {
    try {
      final p = SawaProvider.fromJson(row);
      if (seen.add(p.id)) out.add(p);
    } on FormatException catch (e) {
      debugPrint('Catalog: skipped malformed provider — $e');
    }
  }
  return out;
}
