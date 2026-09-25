import '../../../data/models/catalog_models.dart';

enum ProviderSort { recommended, priceLow, name }

/// Customer search + filters. Only filters the data can actually satisfy
/// are offered in the UI (see [FilterOptions]).
class ProviderFilter {
  const ProviderFilter({
    this.query = '',
    this.categoryId,
    this.area,
    this.maxPrice,
    this.minCapacity,
    this.offersOnly = false,
    this.sort = ProviderSort.recommended,
  });

  final String query;
  final String? categoryId;
  final String? area;
  final double? maxPrice;
  final int? minCapacity;
  final bool offersOnly;
  final ProviderSort sort;

  bool get hasActiveFilters => area != null || maxPrice != null || minCapacity != null || offersOnly;

  ProviderFilter copyWith({
    String? query,
    String? Function()? categoryId,
    String? Function()? area,
    double? Function()? maxPrice,
    int? Function()? minCapacity,
    bool? offersOnly,
    ProviderSort? sort,
  }) =>
      ProviderFilter(
        query: query ?? this.query,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        area: area != null ? area() : this.area,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        minCapacity: minCapacity != null ? minCapacity() : this.minCapacity,
        offersOnly: offersOnly ?? this.offersOnly,
        sort: sort ?? this.sort,
      );

  ProviderFilter cleared() => ProviderFilter(query: query, categoryId: categoryId, sort: sort);
}

/// Arabic-aware normalization for search: unifies alef/ya/ta-marbuta forms,
/// strips diacritics and tatweel, lower-cases Latin.
String normalizeArabic(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(RegExp('[ً-ٰٟـ]'), '');
  s = s
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _haystack(SawaProvider p) => normalizeArabic([
      p.businessName,
      p.shortDescription,
      p.description,
      p.area,
      p.address,
      p.instagramHandle,
      ...p.services.map((s) => s.name),
      ...p.packages.map((k) => k.title),
    ].whereType<String>().join(' '));

List<SawaProvider> applyProviderFilter(List<SawaProvider> input, ProviderFilter f, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final terms = normalizeArabic(f.query).split(' ').where((t) => t.isNotEmpty).toList();
  final out = input.where((p) {
    if (f.categoryId != null && p.categoryId != f.categoryId) return false;
    if (terms.isNotEmpty) {
      final h = _haystack(p);
      if (!terms.every(h.contains)) return false;
    }
    if (f.area != null && !p.areas.any((a) => a.contains(f.area!))) return false;
    if (f.maxPrice != null) {
      final price = p.displayPrice(today);
      if (price == null || price.from > f.maxPrice!) return false;
    }
    if (f.minCapacity != null && (p.capacity == null || p.capacity! < f.minCapacity!)) return false;
    if (f.offersOnly && p.lowestOffer(today) == null) return false;
    return true;
  }).toList();

  switch (f.sort) {
    case ProviderSort.priceLow:
      // Known prices first (ascending); unknown prices keep their order last.
      double key(SawaProvider p) => p.displayPrice(today)?.from ?? double.infinity;
      out.sort((a, b) => key(a).compareTo(key(b)));
    case ProviderSort.name:
      out.sort((a, b) => a.businessName.compareTo(b.businessName));
    case ProviderSort.recommended:
      // Richer, better-documented listings first — a data-quality rule,
      // not a paid ranking and not a rating.
      int richness(SawaProvider p) =>
          (p.cardImageUrl != null ? 3 : 0) +
          (p.galleryImages.isNotEmpty ? 1 : 0) +
          (p.displayPrice(today) != null ? 2 : 0) +
          (p.activePackages(today).isNotEmpty ? 1 : 0);
      out.sort((a, b) => richness(b).compareTo(richness(a)));
  }
  return out;
}

/// Which filters make sense for a set of providers.
class FilterOptions {
  const FilterOptions(
      {required this.areas, required this.priceSteps, required this.hasCapacity, required this.hasOffers});

  final List<String> areas;
  final List<double> priceSteps;
  final bool hasCapacity;
  final bool hasOffers;

  factory FilterOptions.from(List<SawaProvider> list, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final areas = <String>{};
    for (final p in list) {
      for (final a in p.areas) {
        if (!a.contains('توصيل') && a != 'بغداد') areas.add(a);
      }
    }
    final prices = list.map((p) => p.displayPrice(today)?.from).whereType<double>().toList()..sort();
    const candidates = [50000.0, 100000.0, 500000.0, 750000.0, 1000000.0, 1500000.0];
    final steps =
        prices.isEmpty ? <double>[] : candidates.where((c) => c >= prices.first && c <= prices.last * 1.5).toList();
    return FilterOptions(
      areas: areas.toList()..sort(),
      priceSteps: steps,
      hasCapacity: list.any((p) => p.capacity != null),
      hasOffers: list.any((p) => p.lowestOffer(today) != null),
    );
  }
}
