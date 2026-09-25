import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/data/models/catalog_models.dart';
import 'package:sawa/features/providers_list/domain/provider_filter.dart';

void main() {
  final json = jsonDecode(File('assets/data/catalog.json').readAsStringSync()) as Map<String, dynamic>;
  final all = (json['providers'] as List).cast<Map<String, dynamic>>().map(SawaProvider.fromJson).toList();
  final now = DateTime(2026, 9, 25);
  List<String?> ids(List<SawaProvider> l) => l.map((p) => p.legacyId).toList();

  test('Arabic normalization: hamza/ta-marbuta variants match', () {
    expect(normalizeArabic('أساور اللؤلؤ'), normalizeArabic('اساور اللولو'));
    expect(normalizeArabic('قاعة'), 'قاعه');
  });

  test('search finds by name without hamza, by area, and by service', () {
    expect(ids(applyProviderFilter(all, const ProviderFilter(query: 'اساور'), now: now)), ['hall_asawer_001']);
    expect(ids(applyProviderFilter(all, const ProviderFilter(query: 'الجادرية'), now: now)),
        containsAll(['hall_jadriya_001', 'decor_laflamme_001']));
    expect(ids(applyProviderFilter(all, const ProviderFilter(query: 'كوشة ملكية'), now: now)),
        contains('hall_malika_001'));
    expect(applyProviderFilter(all, const ProviderFilter(query: 'xyz-not-there'), now: now), isEmpty);
  });

  test('category + area filters', () {
    final r = applyProviderFilter(all, const ProviderFilter(categoryId: 'halls', area: 'المنصور'), now: now);
    expect(r.every((p) => p.categoryId == 'halls'), isTrue);
    expect(ids(r), containsAll(['hall_asawer_001', 'hall_weam_001']));
  });

  test('max price hides unknown prices instead of guessing', () {
    final r = applyProviderFilter(all, const ProviderFilter(categoryId: 'halls', maxPrice: 800000), now: now);
    expect(ids(r).toSet(), {'hall_ritaj_001', 'hall_rotana_baghdad_001', 'hall_malika_001'});
  });

  test('offers only', () {
    final r = applyProviderFilter(all, const ProviderFilter(offersOnly: true), now: now);
    expect(ids(r).toSet(), {'hall_ritaj_001', 'hall_malika_001', 'hall_asawer_001'});
  });

  test('price sort puts known prices first, ascending', () {
    final r =
        applyProviderFilter(all, const ProviderFilter(categoryId: 'flowers', sort: ProviderSort.priceLow), now: now);
    expect(r.first.legacyId, 'decor_ward_001');
  });

  test('filter options only offer what the data supports', () {
    final photo = all.where((p) => p.categoryId == 'photography').toList();
    final o = FilterOptions.from(photo, now: now);
    expect(o.priceSteps, isEmpty, reason: 'no photographer states a price');
    expect(o.hasCapacity, isFalse);
    expect(o.hasOffers, isFalse);
    final halls = FilterOptions.from(all.where((p) => p.categoryId == 'halls').toList(), now: now);
    expect(halls.hasCapacity, isTrue);
    expect(halls.hasOffers, isTrue);
    expect(halls.areas, contains('المنصور'));
  });
}
