/// The three locked SAWA categories — Baghdad only.
///
/// Source: sawa-product-specification.md (Must Have table: "3 فئات: قاعات،
/// مصورين، ديكور") / sawa-technical-architecture.md §6.
enum ProviderCategory {
  hall,
  photography,
  decor;

  /// The exact string stored in providers.json's `category` field.
  String get id => switch (this) {
        ProviderCategory.hall => 'hall',
        ProviderCategory.photography => 'photography',
        ProviderCategory.decor => 'decor',
      };

  /// Arabic display label, per the product spec's category list.
  String get labelAr => switch (this) {
        ProviderCategory.hall => 'قاعات',
        ProviderCategory.photography => 'مصورين',
        ProviderCategory.decor => 'ديكور',
      };

  static ProviderCategory fromId(String id) {
    return ProviderCategory.values.firstWhere(
      (category) => category.id == id,
      orElse: () =>
          throw FormatException('Unknown provider category id: "$id"'),
    );
  }
}
