import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/features/providers_list/data/provider_category.dart';
import 'package:sawa/features/providers_list/data/provider_model.dart';

void main() {
  group('SawaProvider.fromJson', () {
    test('parses a fully-populated record', () {
      final json = {
        'id': 'hall_001',
        'name': 'قاعة الماسة',
        'category': 'hall',
        'images': ['assets/images/providers/hall_001_1.jpg'],
        'priceRangeText': 'من 500 إلى 1500 ألف دينار',
        'shortDescription': 'قاعة أفراح وسط بغداد، سعة 300 شخص',
        'instagramUrl': 'https://instagram.com/almasa_hall',
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      final provider = SawaProvider.fromJson(json);

      expect(provider.id, 'hall_001');
      expect(provider.category, ProviderCategory.hall);
      expect(provider.images, hasLength(1));
      expect(provider.priceRangeText, isNotNull);
      expect(provider.shortDescription, isNotNull);
      expect(provider.reviewedBySawa, isTrue);
    });

    test('parses a record with both optional fields absent', () {
      final json = {
        'id': 'decor_010',
        'name': 'ديكور تجريبي',
        'category': 'decor',
        'images': ['assets/images/providers/decor_010_1.jpg'],
        'instagramUrl': 'https://instagram.com/example_decor',
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      final provider = SawaProvider.fromJson(json);

      expect(provider.priceRangeText, isNull);
      expect(provider.shortDescription, isNull);
    });

    test('round-trips through toJson for a fully-populated record', () {
      final json = {
        'id': 'photo_001',
        'name': 'استديو الضوء',
        'category': 'photography',
        'images': ['a.jpg', 'b.jpg'],
        'priceRangeText': 'يبدأ من 300 ألف دينار',
        'shortDescription': 'تصوير أعراس وخطوبة',
        'instagramUrl': 'https://instagram.com/light_studio',
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      final roundTripped = SawaProvider.fromJson(json).toJson();

      expect(roundTripped, json);
    });

    test('throws FormatException when "images" is missing', () {
      final json = {
        'id': 'x',
        'name': 'x',
        'category': 'hall',
        'instagramUrl': 'https://instagram.com/x',
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      expect(() => SawaProvider.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when "images" is an empty list', () {
      final json = {
        'id': 'x',
        'name': 'x',
        'category': 'hall',
        'images': <String>[],
        'instagramUrl': 'https://instagram.com/x',
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      expect(() => SawaProvider.fromJson(json), throwsFormatException);
    });

    test('throws FormatException for an unknown category id', () {
      final json = {
        'id': 'x',
        'name': 'x',
        'category': 'catering', // not a locked SAWA category
        'images': ['a.jpg'],
        'instagramUrl': 'https://instagram.com/x',
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      expect(() => SawaProvider.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when "instagramUrl" is missing', () {
      final json = {
        'id': 'x',
        'name': 'x',
        'category': 'hall',
        'images': ['a.jpg'],
        'city': 'بغداد',
        'reviewedBySawa': true,
      };

      expect(() => SawaProvider.fromJson(json), throwsFormatException);
    });
  });

  group('ProviderCategory', () {
    test('id/labelAr cover exactly the 3 locked categories', () {
      expect(ProviderCategory.values, hasLength(3));
      expect(ProviderCategory.hall.id, 'hall');
      expect(ProviderCategory.photography.id, 'photography');
      expect(ProviderCategory.decor.id, 'decor');
    });

    test('fromId round-trips every category', () {
      for (final category in ProviderCategory.values) {
        expect(ProviderCategory.fromId(category.id), category);
      }
    });

    test('fromId throws FormatException for an unknown id', () {
      expect(
        () => ProviderCategory.fromId('catering'),
        throwsFormatException,
      );
    });
  });
}
