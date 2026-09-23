import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sawa/core/constants/app_strings.dart';
import 'package:sawa/core/theme/app_theme.dart';
import 'package:sawa/features/providers_list/data/provider_category.dart';
import 'package:sawa/features/providers_list/data/provider_model.dart';
import 'package:sawa/features/providers_list/presentation/provider_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.light,
          home: Scaffold(body: child),
        ),
      );

  group('ProviderCard', () {
    test('SawaProvider model: optional fields are nullable', () {
      const full = SawaProvider(
        id: 'h1',
        name: 'قاعة النور',
        category: ProviderCategory.hall,
        images: ['assets/images/dev_fixtures/placeholder_4x3.png'],
        priceRangeText: '٥٠٠,٠٠٠ دينار',
        shortDescription: 'وصف قصير',
        instagramUrl: 'https://www.instagram.com/',
        city: 'بغداد',
        reviewedBySawa: true,
      );
      expect(full.priceRangeText, isNotNull);
      expect(full.shortDescription, isNotNull);

      const minimal = SawaProvider(
        id: 'h2',
        name: 'قاعة بسيطة',
        category: ProviderCategory.hall,
        images: ['a.png'],
        instagramUrl: 'https://www.instagram.com/',
        city: 'بغداد',
        reviewedBySawa: true,
      );
      expect(minimal.priceRangeText, isNull);
      expect(minimal.shortDescription, isNull);
    });

    testWidgets(
        'renders provider name and reviewed badge for a fully-populated provider',
        (tester) async {
      const provider = SawaProvider(
        id: 'hall_001',
        name: 'قاعة الوركاء',
        category: ProviderCategory.hall,
        images: ['assets/images/dev_fixtures/placeholder_4x3.png'],
        priceRangeText: '٥٠٠,٠٠٠ دينار',
        shortDescription: 'قاعة في قلب بغداد',
        instagramUrl: 'https://www.instagram.com/',
        city: 'بغداد',
        reviewedBySawa: true,
      );

      await tester.pumpWidget(wrap(
        const SingleChildScrollView(child: ProviderCard(provider: provider)),
      ));
      await tester.pump();

      expect(find.text('قاعة الوركاء'), findsOneWidget);
      expect(find.text(AppStrings.reviewedBadge), findsOneWidget);
      expect(find.text('٥٠٠,٠٠٠ دينار'), findsOneWidget);
      expect(find.text('قاعة في قلب بغداد'), findsOneWidget);
    });

    testWidgets(
        'renders correctly when both optional fields (priceRangeText and '
        'shortDescription) are absent', (tester) async {
      const provider = SawaProvider(
        id: 'photo_001',
        name: 'استديو الضوء',
        category: ProviderCategory.photography,
        images: ['assets/images/dev_fixtures/placeholder_4x3.png'],
        instagramUrl: 'https://www.instagram.com/',
        city: 'بغداد',
        reviewedBySawa: true,
      );

      await tester.pumpWidget(wrap(
        const SingleChildScrollView(child: ProviderCard(provider: provider)),
      ));
      await tester.pump();

      expect(find.text('استديو الضوء'), findsOneWidget);
      expect(find.text(AppStrings.reviewedBadge), findsOneWidget);
      // Optional fields must be absent, not replaced by "غير متوفر" (DA3)
      expect(find.text('غير متوفر'), findsNothing);
    });

    testWidgets('EmptyStateView renders the provided message', (tester) async {
      await tester.pumpWidget(wrap(
        const SingleChildScrollView(
          child: Center(
            child: Text(AppStrings.categoryEmptyState),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text(AppStrings.categoryEmptyState), findsOneWidget);
    });
  });
}
