import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/features/providers_list/data/provider_category.dart';
import 'package:sawa/features/providers_list/data/providers_repository.dart';

/// A minimal fake AssetBundle that serves fixed JSON text for
/// [ProvidersRepository.assetPath], without touching real Flutter assets.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._contents);
  final String _contents;

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      _contents;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError('Only loadString is exercised by these tests.');
  }
}

void main() {
  test('getAll() parses a valid array of providers', () async {
    const json = '''
    [
      {"id": "hall_1", "name": "قاعة 1", "category": "hall",
       "images": ["a.jpg"], "instagramUrl": "https://instagram.com/a",
       "city": "بغداد", "reviewedBySawa": true},
      {"id": "photo_1", "name": "مصور 1", "category": "photography",
       "images": ["b.jpg"], "instagramUrl": "https://instagram.com/b",
       "city": "بغداد", "reviewedBySawa": true}
    ]
    ''';
    final repo = ProvidersRepository(bundle: _FakeAssetBundle(json));

    final result = await repo.getAll();

    expect(result, hasLength(2));
  });

  test('getAll() returns an empty list for an empty array (real default '
      'providers.json state)', () async {
    final repo = ProvidersRepository(bundle: _FakeAssetBundle('[]'));

    final result = await repo.getAll();

    expect(result, isEmpty);
  });

  test('getAll() skips a malformed record instead of throwing', () async {
    const json = '''
    [
      {"id": "ok_1", "name": "x", "category": "hall", "images": ["a.jpg"],
       "instagramUrl": "https://instagram.com/a", "city": "بغداد",
       "reviewedBySawa": true},
      {"id": "bad_1", "name": "missing images", "category": "hall",
       "instagramUrl": "https://instagram.com/a", "city": "بغداد",
       "reviewedBySawa": true}
    ]
    ''';
    final repo = ProvidersRepository(bundle: _FakeAssetBundle(json));

    final result = await repo.getAll();

    expect(result, hasLength(1));
    expect(result.single.id, 'ok_1');
  });

  test(
      'getAll() drops a duplicate id, keeping only the first occurrence',
      () async {
    const json = '''
    [
      {"id": "dup", "name": "first", "category": "hall", "images": ["a.jpg"],
       "instagramUrl": "https://instagram.com/a", "city": "بغداد",
       "reviewedBySawa": true},
      {"id": "dup", "name": "second", "category": "hall", "images": ["b.jpg"],
       "instagramUrl": "https://instagram.com/b", "city": "بغداد",
       "reviewedBySawa": true}
    ]
    ''';
    final repo = ProvidersRepository(bundle: _FakeAssetBundle(json));

    final result = await repo.getAll();

    expect(result, hasLength(1));
    expect(result.single.name, 'first');
  });

  test('getAll() returns an empty list when the top level is not an array',
      () async {
    final repo = ProvidersRepository(bundle: _FakeAssetBundle('{}'));

    final result = await repo.getAll();

    expect(result, isEmpty);
  });

  test('getByCategory() filters to a single category', () async {
    const json = '''
    [
      {"id": "h1", "name": "x", "category": "hall", "images": ["a.jpg"],
       "instagramUrl": "https://instagram.com/a", "city": "بغداد",
       "reviewedBySawa": true},
      {"id": "p1", "name": "y", "category": "photography",
       "images": ["b.jpg"], "instagramUrl": "https://instagram.com/b",
       "city": "بغداد", "reviewedBySawa": true}
    ]
    ''';
    final repo = ProvidersRepository(bundle: _FakeAssetBundle(json));

    final halls = await repo.getByCategory(ProviderCategory.hall);

    expect(halls, hasLength(1));
    expect(halls.single.id, 'h1');
  });
}
