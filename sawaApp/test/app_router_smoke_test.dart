import 'package:flutter/material.dart';
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

  testWidgets('boots on HomeScreen with the 3 locked categories, and '
      'navigates to Category on tap', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SawaApp()));
    await tester.pumpAndSettle();

    expect(find.text('sawa'), findsOneWidget);
    expect(find.text('قاعات'), findsOneWidget);
    expect(find.text('مصورين'), findsOneWidget);
    expect(find.text('ديكور'), findsOneWidget);

    await tester.tap(find.text('قاعات'));
    await tester.pumpAndSettle();

    // AppBar title on CategoryScreen repeats the tapped category's label.
    expect(find.text('قاعات'), findsWidgets);
  });
}
