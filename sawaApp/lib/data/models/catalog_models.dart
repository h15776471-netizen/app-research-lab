import 'json_utils.dart';

/// A row of `public.categories`.
class SawaCategory {
  const SawaCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.iconKey,
    required this.sortOrder,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String iconKey;
  final int sortOrder;

  factory SawaCategory.fromJson(Map<String, dynamic> j) => SawaCategory(
        id: reqStr(j, 'id'),
        nameAr: reqStr(j, 'name_ar'),
        nameEn: str(j['name_en']) ?? '',
        iconKey: str(j['icon_key']) ?? 'sparkle',
        sortOrder: intOrNull(j['sort_order']) ?? 0,
      );
}

/// Provenance of one provider field (`public.provider_field_sources`).
enum FieldStatus {
  verified,
  sourceOnly,
  unverified,
  missing;

  static FieldStatus parse(String? v) => switch (v) {
        'verified' => FieldStatus.verified,
        'source_only' => FieldStatus.sourceOnly,
        'unverified' => FieldStatus.unverified,
        _ => FieldStatus.missing,
      };

  String get dbValue => switch (this) {
        FieldStatus.verified => 'verified',
        FieldStatus.sourceOnly => 'source_only',
        FieldStatus.unverified => 'unverified',
        FieldStatus.missing => 'missing',
      };
}

class FieldSource {
  const FieldSource({required this.field, required this.status, this.note});

  final String field;
  final FieldStatus status;
  final String? note;

  factory FieldSource.fromJson(Map<String, dynamic> j) => FieldSource(
        field: reqStr(j, 'field'),
        status: FieldStatus.parse(str(j['status'])),
        note: str(j['note']),
      );
}

enum ImageKind { cover, gallery, logo }

/// A row of `public.provider_images`. [url] is either a bundled asset path
/// (`assets/...`, SAWA-extracted images) or a public Storage URL (uploads).
class ProviderImage {
  const ProviderImage({
    required this.id,
    required this.url,
    required this.kind,
    required this.sortOrder,
    this.altText,
    this.storagePath,
  });

  final String id;
  final String url;
  final ImageKind kind;
  final int sortOrder;
  final String? altText;
  final String? storagePath;

  factory ProviderImage.fromJson(Map<String, dynamic> j) => ProviderImage(
        id: reqStr(j, 'id'),
        url: reqStr(j, 'url'),
        kind: switch (str(j['kind'])) {
          'cover' => ImageKind.cover,
          'logo' => ImageKind.logo,
          _ => ImageKind.gallery,
        },
        sortOrder: intOrNull(j['sort_order']) ?? 0,
        altText: str(j['alt_text']),
        storagePath: str(j['storage_path']),
      );
}

/// Units allowed by `services_unit_check`.
const serviceUnits = <String, String>{
  'event': 'للمناسبة',
  'person': 'للشخص',
  'hour': 'للساعة',
  'day': 'لليوم',
  'piece': 'للقطعة',
  'package': 'للباقة',
};

/// A row of `public.services`.
class ProviderService {
  const ProviderService({
    required this.id,
    required this.providerId,
    required this.name,
    this.description,
    this.priceFrom,
    this.priceTo,
    this.currency = 'IQD',
    this.unit,
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String providerId;
  final String name;
  final String? description;
  final double? priceFrom;
  final double? priceTo;
  final String currency;
  final String? unit;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;

  factory ProviderService.fromJson(Map<String, dynamic> j) => ProviderService(
        id: reqStr(j, 'id'),
        providerId: reqStr(j, 'provider_id'),
        name: reqStr(j, 'name'),
        description: str(j['description']),
        priceFrom: numOrNull(j['price_from']),
        priceTo: numOrNull(j['price_to']),
        currency: str(j['currency']) ?? 'IQD',
        unit: str(j['unit']),
        imageUrl: str(j['image_url']),
        isActive: j['is_active'] != false,
        sortOrder: intOrNull(j['sort_order']) ?? 0,
      );
}

/// A row of `public.provider_packages` — a package, or a time-bound offer
/// when [isOffer] (never shown as the provider's base price).
class ProviderPackage {
  const ProviderPackage({
    required this.id,
    required this.providerId,
    required this.title,
    this.description,
    this.priceFrom,
    this.priceTo,
    this.currency = 'IQD',
    this.conditions,
    this.isOffer = false,
    this.validFrom,
    this.validUntil,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String providerId;
  final String title;
  final String? description;
  final double? priceFrom;
  final double? priceTo;
  final String currency;
  final String? conditions;
  final bool isOffer;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final int sortOrder;

  /// An offer whose end date has passed is not shown to customers.
  bool isExpired(DateTime now) =>
      validUntil != null &&
      DateTime(validUntil!.year, validUntil!.month, validUntil!.day).isBefore(DateTime(now.year, now.month, now.day));

  factory ProviderPackage.fromJson(Map<String, dynamic> j) => ProviderPackage(
        id: reqStr(j, 'id'),
        providerId: reqStr(j, 'provider_id'),
        title: reqStr(j, 'title'),
        description: str(j['description']),
        priceFrom: numOrNull(j['price_from']),
        priceTo: numOrNull(j['price_to']),
        currency: str(j['currency']) ?? 'IQD',
        conditions: str(j['conditions']),
        isOffer: j['is_offer'] == true,
        validFrom: dateOrNull(j['valid_from']),
        validUntil: dateOrNull(j['valid_until']),
        isActive: j['is_active'] != false,
        sortOrder: intOrNull(j['sort_order']) ?? 0,
      );
}

enum ListingStatus {
  draft,
  pending,
  published,
  suspended;

  static ListingStatus parse(String? v) => switch (v) {
        'pending' => ListingStatus.pending,
        'published' => ListingStatus.published,
        'suspended' => ListingStatus.suspended,
        _ => ListingStatus.draft,
      };

  String get dbValue => name;

  String get labelAr => switch (this) {
        ListingStatus.draft => 'مسودة',
        ListingStatus.pending => 'قيد المراجعة',
        ListingStatus.published => 'منشور',
        ListingStatus.suspended => 'موقوف',
      };
}

/// A price the UI may show, with an honest label of what it is.
class DisplayPrice {
  const DisplayPrice({required this.from, this.to, required this.isOffer});

  final double from;
  final double? to;
  final bool isOffer;
}

/// A business listing (`public.providers`) with its public children.
class SawaProvider {
  const SawaProvider({
    required this.id,
    required this.categoryId,
    required this.businessName,
    required this.city,
    required this.status,
    this.legacyId,
    this.userId,
    this.shortDescription,
    this.description,
    this.area,
    this.address,
    this.instagramUrl,
    this.website,
    this.coverImageUrl,
    this.capacity,
    this.priceFrom,
    this.priceTo,
    this.currency = 'IQD',
    this.priceNote,
    this.source = 'self_registered',
    this.images = const [],
    this.services = const [],
    this.packages = const [],
    this.fieldSources = const {},
  });

  final String id;
  final String? legacyId;
  final String? userId;
  final String categoryId;
  final String businessName;
  final String? shortDescription;
  final String? description;
  final String city;
  final String? area;
  final String? address;
  final String? instagramUrl;
  final String? website;
  final String? coverImageUrl;
  final int? capacity;
  final double? priceFrom;
  final double? priceTo;
  final String currency;
  final String? priceNote;
  final ListingStatus status;
  final String source;
  final List<ProviderImage> images;
  final List<ProviderService> services;
  final List<ProviderPackage> packages;
  final Map<String, FieldSource> fieldSources;

  factory SawaProvider.fromJson(Map<String, dynamic> j) {
    final images = rows(j['images']).map(ProviderImage.fromJson).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final services = rows(j['services']).map(ProviderService.fromJson).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final packages = rows(j['packages']).map(ProviderPackage.fromJson).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final sources = {
      for (final f in rows(j['field_sources']).map(FieldSource.fromJson)) f.field: f,
    };
    return SawaProvider(
      id: reqStr(j, 'id'),
      legacyId: str(j['legacy_id']),
      userId: str(j['user_id']),
      categoryId: reqStr(j, 'category_id'),
      businessName: reqStr(j, 'business_name'),
      shortDescription: str(j['short_description']),
      description: str(j['description']),
      city: str(j['city']) ?? 'بغداد',
      area: str(j['area']),
      address: str(j['address']),
      instagramUrl: str(j['instagram_url']),
      website: str(j['website']),
      coverImageUrl: str(j['cover_image_url']),
      capacity: intOrNull(j['capacity']),
      priceFrom: numOrNull(j['price_from']),
      priceTo: numOrNull(j['price_to']),
      currency: str(j['currency']) ?? 'IQD',
      priceNote: str(j['price_note']),
      status: ListingStatus.parse(str(j['status'])),
      source: str(j['source']) ?? 'self_registered',
      images: images,
      services: services,
      packages: packages,
      fieldSources: sources,
    );
  }

  FieldStatus fieldStatus(String field) => fieldSources[field]?.status ?? FieldStatus.missing;

  bool get isSawaManaged => source == 'pdf';

  /// The image that represents the listing on cards — the explicit cover,
  /// else `cover_image_url`. A gallery image is never promoted to cover
  /// (e.g. dish photos must not become a hall's cover); callers fall back
  /// to the branded placeholder.
  String? get cardImageUrl {
    for (final i in images) {
      if (i.kind == ImageKind.cover) return i.url;
    }
    return coverImageUrl;
  }

  List<ProviderImage> get galleryImages => images.where((i) => i.kind != ImageKind.logo).toList(growable: false);

  List<ProviderService> get activeServices => services.where((s) => s.isActive).toList(growable: false);

  List<ProviderPackage> activePackages(DateTime now) =>
      packages.where((p) => p.isActive && !p.isExpired(now)).toList(growable: false);

  /// "Starting from" price: the provider's stated price, else the cheapest
  /// non-offer package. Offers are never presented as the base price.
  DisplayPrice? basePrice(DateTime now) {
    if (priceFrom != null) {
      return DisplayPrice(from: priceFrom!, to: priceTo, isOffer: false);
    }
    final priced = activePackages(now).where((p) => !p.isOffer && p.priceFrom != null).toList();
    if (priced.isEmpty) return null;
    priced.sort((a, b) => a.priceFrom!.compareTo(b.priceFrom!));
    return DisplayPrice(from: priced.first.priceFrom!, isOffer: false);
  }

  /// The cheapest currently active offer, labelled as an offer.
  DisplayPrice? lowestOffer(DateTime now) {
    final offers = activePackages(now).where((p) => p.isOffer && p.priceFrom != null).toList();
    if (offers.isEmpty) return null;
    offers.sort((a, b) => a.priceFrom!.compareTo(b.priceFrom!));
    return DisplayPrice(from: offers.first.priceFrom!, isOffer: true);
  }

  /// Base price if known, else the lowest offer (clearly flagged).
  DisplayPrice? displayPrice(DateTime now) => basePrice(now) ?? lowestOffer(now);

  String? get instagramHandle {
    final url = instagramUrl;
    if (url == null) return null;
    final m = RegExp(r'instagram\.com/([A-Za-z0-9._]+)').firstMatch(url);
    return m?.group(1);
  }

  /// Areas split for filtering ("المنصور · الكرادة" → two areas).
  List<String> get areas =>
      (area ?? '').split('·').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(growable: false);
}
