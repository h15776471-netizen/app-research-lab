import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sawa/core/theme/app_theme.dart';
import 'package:sawa/features/contact_request/presentation/contact_request_screen.dart';
import 'package:sawa/features/contact_request/state/contact_request_notifier.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.light,
          home: child,
        ),
      );

  group('ContactRequestScreen', () {
    testWidgets(
        'submit button is initially disabled when required fields are empty',
        (tester) async {
      await tester.pumpWidget(
        wrap(const ContactRequestScreen(providerId: 'hall_001')),
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'إرسال الطلب'),
      );
      expect(button.onPressed, isNull,
          reason: 'submit button must be disabled when fields are empty');
    });

    testWidgets(
        'submit button becomes enabled once both required fields are filled',
        (tester) async {
      await tester.pumpWidget(
        wrap(const ContactRequestScreen(providerId: 'hall_001')),
      );
      await tester.pump();

      // Fill name field
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسمك الكريم'),
        'زينب أحمد',
      );
      await tester.pump();

      // Still disabled — phone not filled
      var button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'إرسال الطلب'),
      );
      expect(button.onPressed, isNull);

      // Fill phone field
      await tester.enterText(
        find.widgetWithText(TextFormField, 'رقم هاتفك أو واتساب'),
        '+9647701234567',
      );
      await tester.pump();

      // Now enabled
      button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'إرسال الطلب'),
      );
      expect(button.onPressed, isNotNull,
          reason: 'submit button must be enabled once required fields filled');
    });

    testWidgets('submit button shows loading state when submitting',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactRequestNotifierProvider.overrideWith(
              () => _SubmittingNotifier(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            theme: AppTheme.light,
            home: const ContactRequestScreen(providerId: 'hall_001'),
          ),
        ),
      );
      await tester.pump();

      // CircularProgressIndicator inside the button signals loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ContactRequestState', () {
    test('initial state: not submitting, not success, no error', () {
      const state = ContactRequestState();
      expect(state.isSubmitting, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.hasError, isFalse);
    });

    test('submitting state: isSubmitting true, others false', () {
      const state = ContactRequestState(isSubmitting: true);
      expect(state.isSubmitting, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.hasError, isFalse);
    });

    test('error state: hasError true', () {
      const state = ContactRequestState(errorMessage: 'some error');
      expect(state.hasError, isTrue);
      expect(state.isSubmitting, isFalse);
      expect(state.isSuccess, isFalse);
    });

    test('success state: isSuccess true', () {
      const state = ContactRequestState(isSuccess: true);
      expect(state.isSuccess, isTrue);
      expect(state.isSubmitting, isFalse);
      expect(state.hasError, isFalse);
    });
  });
}

/// Test-only notifier that immediately enters the submitting state,
/// so widget tests can verify the loading UI without real network calls.
class _SubmittingNotifier extends ContactRequestNotifier {
  @override
  ContactRequestState build() => const ContactRequestState(isSubmitting: true);
}
