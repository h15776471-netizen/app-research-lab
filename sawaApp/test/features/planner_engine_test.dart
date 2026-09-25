import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/data/models/account_models.dart';
import 'package:sawa/data/models/catalog_models.dart';
import 'package:sawa/features/customer/event_planner/domain/planner_engine.dart';

SawaProvider hall(String id, {int? capacity, String? area, double? price, bool offer = false}) => SawaProvider(
      id: id,
      categoryId: 'halls',
      businessName: 'قاعة $id',
      city: 'بغداد',
      status: ListingStatus.published,
      area: area,
      capacity: capacity,
      priceFrom: offer ? null : price,
      packages: [
        if (offer && price != null)
          ProviderPackage(id: 'k$id', providerId: id, title: 'عرض', priceFrom: price, isOffer: true),
      ],
    );

void main() {
  final now = DateTime(2026, 9, 25);

  test('only requested categories are considered', () {
    const photo = SawaProvider(
        id: 'p', categoryId: 'photography', businessName: 'مصور', city: 'بغداد', status: ListingStatus.published);
    final r = matchProviders(
        [hall('a'), photo], const PlannerCriteria(eventType: EventType.wedding, categoryIds: ['halls']),
        now: now);
    expect(r.byCategory.keys, ['halls']);
    expect(r.byCategory['halls']!.map((m) => m.provider.id), ['a']);
  });

  test('stated capacity below guest count excludes; unknown capacity does not', () {
    final r = matchProviders(
      [hall('small', capacity: 100), hall('big', capacity: 300), hall('unknown')],
      const PlannerCriteria(eventType: EventType.wedding, categoryIds: ['halls'], guestCount: 200),
      now: now,
    );
    expect(r.excluded.map((m) => m.provider.id), ['small']);
    final ids = r.byCategory['halls']!.map((m) => m.provider.id).toList();
    expect(ids.first, 'big');
    expect(ids, contains('unknown'));
    final unknown = r.byCategory['halls']!.firstWhere((m) => m.provider.id == 'unknown');
    expect(unknown.reasons.any((x) => x.text.contains('غير متوفرة')), isTrue);
  });

  test('area and budget add explainable points; missing price is neutral', () {
    final r = matchProviders(
      [
        hall('near-cheap', area: 'المنصور', price: 700000),
        hall('far-expensive', area: 'زيونة', price: 2000000),
        hall('no-price', area: 'المنصور'),
      ],
      const PlannerCriteria(eventType: EventType.wedding, categoryIds: ['halls'], area: 'المنصور', budgetMax: 1000000),
      now: now,
    );
    final ranked = r.byCategory['halls']!;
    expect(ranked.first.provider.id, 'near-cheap');
    expect(ranked.last.provider.id, 'far-expensive');
    expect(ranked.first.reasons.where((x) => x.kind == ReasonKind.match).length, greaterThanOrEqualTo(2));
    final noPrice = ranked.firstWhere((m) => m.provider.id == 'no-price');
    expect(noPrice.reasons.any((x) => x.text.contains('السعر غير متوفر')), isTrue);
    expect(r.excluded, isEmpty, reason: 'budget never excludes');
  });

  test('offers are labelled as offers in reasons', () {
    final r = matchProviders(
      [hall('o', price: 500000, offer: true)],
      const PlannerCriteria(eventType: EventType.wedding, categoryIds: ['halls'], budgetMax: 600000),
      now: now,
    );
    expect(r.byCategory['halls']!.single.reasons.first.text, startsWith('عرض'));
  });

  test('knownAreas lists only real Baghdad areas from the data', () {
    final areas = knownAreas([
      hall('a', area: 'المنصور · الكرادة'),
      const SawaProvider(
          id: 'w',
          categoryId: 'flowers',
          businessName: 'ورد',
          city: 'بغداد',
          status: ListingStatus.published,
          area: 'توصيل داخل بغداد'),
    ]);
    expect(areas, ['الكرادة', 'المنصور']);
  });
}
