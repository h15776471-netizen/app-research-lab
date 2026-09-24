import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sawa/app.dart';

void main() {
  setUpAll(() {
    // Avoid GoogleFonts trying to fetch font files over the network during
    // widget tests (a common testing pitfall with this package).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
      'boots through splash to welcome screen (unauthenticated); '
      'welcome screen has sign-in, sign-up, and guest-browse actions',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SawaApp()));

    // Allow auth session restore to complete. Supabase is not initialized in
    // tests, so AuthNotifier._restoreSession() catches the StateError and sets
    // isLoading=false. The router redirect then fires: /splash → /welcome.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // App branding visible on WelcomeScreen.
    expect(find.text('sawa'), findsWidgets);

    // All three primary actions on WelcomeScreen are present.
    expect(find.text('إنشاء حساب'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('تصفح بدون تسجيل'), findsOneWidget);
  });
}
