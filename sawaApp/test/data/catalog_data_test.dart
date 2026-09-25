import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/data/models/catalog_models.dart';

/// Guards the data-integrity decisions on the REAL bundled catalog
/// (generated from provider-data/catalog/providers.v2.json).
void main() {
  final json = jsonDecode(File('assets/data/catalog.json').readAsStringSync()) as Map<String, dynamic>;
  final providers = (json['providers'] as List).cast<Map<String, dynamic>>().map(SawaProvider.fromJson).toList();
  final byLegacy = {for (final p in providers) p.legacyId!: p};
  final now = DateTime(2026, 9, 25);

  test('15 published providers: 6 halls, 5 photography, 4 flowers', () {
    expect(providers, hasLength(15));
    expect(providers.every((p) => p.status == ListingStatus.published), isTrue);
    int count(String c) => providers.where((p) => p.categoryId == c).length;
    expect(count('halls'), 6);
    expect(count('photography'), 5);
    expect(count('flowers'), 4);
    expect(count('decoration'), 0, reason: 'Decoration stays an honest empty category');
  });

  test('ids are unique uuids and legacy ids are preserved', () {
    expect(providers.map((p) => p.id).toSet(), hasLength(15));
    expect(byLegacy.keys, contains('hall_ritaj_001'));
  });

  test('draft listings (no Instagram in source) are not shipped', () {
    expect(byLegacy.containsKey('hall_almas_001'), isFalse);
    expect(byLegacy.containsKey('hall_qasr_rotana_001'), isFalse);
  });

  test('every referenced image exists and none is a PDF page render', () {
    for (final p in providers) {
      final urls = [
        ...p.images.map((i) => i.url),
        ...p.services.map((s) => s.imageUrl).whereType<String>(),
        if (p.coverImageUrl != null) p.coverImageUrl!,
      ];
      for (final u in urls) {
        expect(File(u).existsSync(), isTrue, reason: '$u missing (${p.legacyId})');
        expect(u.contains('preview'), isFalse, reason: 'v1 PDF render still referenced: $u');
      }
    }
  });

  test('no invented images: Ritaj and Rotana have none; Jadriya dishes are never the cover', () {
    expect(byLegacy['hall_ritaj_001']!.images, isEmpty);
    expect(byLegacy['hall_rotana_baghdad_001']!.images, isEmpty);
    final jad = byLegacy['hall_jadriya_001']!;
    expect(jad.galleryImages, isNotEmpty);
    expect(jad.cardImageUrl, isNull);
  });

  test('ambiguous Instagram handles are not linked (Ward, Tabarek)', () {
    for (final id in ['decor_ward_001', 'photo_tabarek_001']) {
      final p = byLegacy[id]!;
      expect(p.instagramUrl, isNull, reason: id);
      expect(p.fieldStatus('instagram_url'), FieldStatus.unverified, reason: id);
    }
    expect(byLegacy['hall_ritaj_001']!.instagramHandle, 'ritajhall');
  });

  test('Fayrouz has no price (v1 had Ward\'s list by mistake)', () {
    final p = byLegacy['decor_fayrouz_001']!;
    expect(p.displayPrice(now), isNull);
    expect(p.fieldStatus('price'), FieldStatus.missing);
  });

  test('offers are never the base price', () {
    final ritaj = byLegacy['hall_ritaj_001']!;
    expect(ritaj.basePrice(now), isNull);
    expect(ritaj.lowestOffer(now)!.from, 500000);
    expect(ritaj.displayPrice(now)!.isOffer, isTrue);

    final asawer = byLegacy['hall_asawer_001']!;
    expect(asawer.basePrice(now), isNull);
    expect(asawer.lowestOffer(now)!.from, 1350000);

    final rotana = byLegacy['hall_rotana_baghdad_001']!;
    expect(rotana.basePrice(now)!.from, 750000);
    expect(rotana.basePrice(now)!.to, 1000000);
    expect(rotana.basePrice(now)!.isOffer, isFalse);
  });

  test('capacity only where the source states it', () {
    expect(byLegacy['hall_jadriya_001']!.capacity, 200);
    expect(providers.where((p) => p.capacity != null).map((p) => p.legacyId), ['hall_jadriya_001']);
  });

  test('no provider phone numbers ship in the public catalog', () {
    final raw = File('assets/data/catalog.json').readAsStringSync();
    for (final phone in ['07724000038', '07700001150', '07817114400', '07714244730']) {
      expect(raw.contains(phone), isFalse, reason: 'private phone $phone leaked');
    }
  });

  test('nothing is marked verified (no verification mechanism exists yet)', () {
    for (final p in providers) {
      expect(p.fieldSources.values.any((f) => f.status == FieldStatus.verified), isFalse, reason: p.legacyId);
    }
  });
}
