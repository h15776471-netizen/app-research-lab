import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sawa/app.dart';
import 'package:sawa/data/data_providers.dart';

/// End-to-end smoke tests in offline catalog mode (no Supabase): the real
/// bundled catalog, real router, real screens.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> boot(WidgetTester tester, {Size size = const Size(420, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [supabaseClientProvider.overrideWithValue(null)],
      child: const SawaApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('boots to welcome; guest can browse without an account', (tester) async {
    await boot(tester);
    expect(find.text('تصفح بدون تسجيل'), findsOneWidget);
    // Account actions are always offered; offline builds also state why
    // they cannot complete yet.
    expect(find.text('إنشاء حساب'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.textContaining('غير متصلة بخادم SAWA'), findsOneWidget);

    await tester.tap(find.text('تصفح بدون تسجيل'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('الفئات'), findsOneWidget);
    expect(find.text('قاعات المناسبات'), findsWidgets);
    expect(find.text('6 مزود'), findsOneWidget);
    expect(find.text('خطّط مناسبتك'), findsOneWidget);
  });

  testWidgets('welcome opens the login screen', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
  });

  testWidgets('welcome opens the sign-up screen', (tester) async {
    await boot(tester);
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
  });

  testWidgets('category → provider details → contact form (offline shows honest state)', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تصفح بدون تسجيل'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('قاعات المناسبات').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('6 نتيجة'), findsOneWidget);
    // Listings with real photos rank first; Ritaj has none, so scroll to it.
    await tester.dragUntilVisible(
        find.text('قاعة الريتاج للمناسبات'), find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('قاعة الريتاج للمناسبات'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // No genuine photo in the source → honest placeholder, offer labelled.
    expect(find.text('لا توجد صور من المزود بعد'), findsOneWidget);
    expect(find.text('عروض من 500,000 د.ع'), findsWidgets);
    expect(find.text('اطلب تواصل'), findsOneWidget);

    await tester.dragUntilVisible(find.text('عن هذه البيانات'), find.byType(CustomScrollView), const Offset(0, -300));
    expect(find.textContaining('غير متوفر في المصدر'), findsOneWidget);

    await tester.tap(find.text('اطلب تواصل'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('طلب تواصل'), findsOneWidget);
    expect(find.textContaining('غير متصلة بخادم SAWA'), findsOneWidget);
    final send = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'إرسال الطلب'));
    expect(send.onPressed, isNull, reason: 'never a fake success while offline');
  });

  testWidgets('explore search finds a provider by Arabic name without hamza', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تصفح بدون تسجيل'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('اكتشف'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField).first, 'اساور');
    await tester.pumpAndSettle();
    expect(find.text('قاعة أساور اللؤلؤ الملكية'), findsOneWidget);
    expect(find.text('1 نتيجة'), findsOneWidget);
  });

  testWidgets('planner walks through steps and explains rule-based results', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تصفح بدون تسجيل'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('خطّط مناسبتك'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('زفاف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قاعات المناسبات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('200'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعرض الخيارات'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('وليس ذكاءً اصطناعياً'), findsOneWidget);
    expect(find.text('مطعم وحدائق الجادرية — قاعة الخاتون'), findsOneWidget);
    expect(find.textContaining('تتسع لـ200 ضيف'), findsOneWidget);
  });

  testWidgets('wide layout uses a navigation rail and a card grid', (tester) async {
    await boot(tester, size: const Size(1400, 900));
    await tester.tap(find.text('تصفح بدون تسجيل'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
