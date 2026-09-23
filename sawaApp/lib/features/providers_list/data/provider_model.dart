import 'provider_category.dart';

/// The SAWA provider entity (a vendor: hall / photographer / decor studio).
///
/// Source: sawa-technical-architecture.md §6. Fields, nullability, and
/// semantics below are copied exactly from that table.
///
/// NAMING NOTE (engineering decision, not a product decision): the locked
/// docs call this entity "Provider". This Dart class is named
/// [SawaProvider] instead of the literal `Provider` only to avoid
/// colliding with Riverpod's own `Provider<T>` type, used throughout this
/// codebase (see providers_list_notifier.dart). No field, behavior, or
/// JSON shape is affected by this rename.
class SawaProvider {
  const SawaProvider({
    required this.id,
    required this.name,
    required this.category,
    required this.images,
    required this.instagramUrl,
    required this.city,
    required this.reviewedBySawa,
    this.priceRangeText,
    this.shortDescription,
  });

  final String id;
  final String name;
  final ProviderCategory category;

  /// At least one image path/URL — required. Enforced in [fromJson].
  final List<String> images;

  /// Optional. Hidden entirely in the UI when null — never rendered as
  /// "غير متوفر" (Product Spec / Design Handoff DA3, a non-negotiable
  /// product decision, not a style preference).
  final String? priceRangeText;

  /// Optional. Same silent-hide rule as [priceRangeText].
  final String? shortDescription;

  /// The provider's original Instagram source. Required, and must never be
  /// hidden from the user — locked Product Decision #3.
  final String instagramUrl;

  /// Fixed to "بغداد" for this MVP (Baghdad-only scope).
  final String city;

  /// Drives the "تمت مراجعته من فريق sawa" badge. Always `true` for any
  /// provider present in the real dataset. Never render the word "موثّق"
  /// anywhere this is surfaced.
  final bool reviewedBySawa;

  /// NOTE: deliberately no `phoneNumber` field. The provider's phone
  /// number is never shown in-app — Skill Module 5 hard rule. If a future
  /// data export ever adds one to the raw JSON, it must not be wired here.
  factory SawaProvider.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final categoryId = json['category'];
    final rawImages = json['images'];
    final instagramUrl = json['instagramUrl'];
    final city = json['city'];
    final reviewedBySawa = json['reviewedBySawa'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Provider is missing required "id".');
    }
    if (name is! String || name.isEmpty) {
      throw const FormatException('Provider is missing required "name".');
    }
    if (categoryId is! String) {
      throw const FormatException('Provider is missing required "category".');
    }
    final images = (rawImages is List)
        ? rawImages.whereType<String>().toList(growable: false)
        : const <String>[];
    if (images.isEmpty) {
      throw const FormatException(
        'Provider "$id" is missing at least one required image.',
      );
    }
    if (instagramUrl is! String || instagramUrl.isEmpty) {
      throw const FormatException(
        'Provider is missing required "instagramUrl".',
      );
    }
    if (city is! String || city.isEmpty) {
      throw const FormatException('Provider is missing required "city".');
    }
    if (reviewedBySawa is! bool) {
      throw const FormatException(
        'Provider is missing required "reviewedBySawa".',
      );
    }

    return SawaProvider(
      id: id,
      name: name,
      category: ProviderCategory.fromId(categoryId),
      images: images,
      instagramUrl: instagramUrl,
      city: city,
      reviewedBySawa: reviewedBySawa,
      priceRangeText: json['priceRangeText'] as String?,
      shortDescription: json['shortDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.id,
        'images': images,
        if (priceRangeText != null) 'priceRangeText': priceRangeText,
        if (shortDescription != null) 'shortDescription': shortDescription,
        'instagramUrl': instagramUrl,
        'city': city,
        'reviewedBySawa': reviewedBySawa,
      };
}
