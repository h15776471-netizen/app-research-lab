import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'sawa_wordmark.dart';

/// Shown while the Supabase session restores; the router moves on as soon
/// as auth state settles.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.gradientHero),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SawaWordmark(light: true, size: 44),
            SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.champagne),
            ),
          ]),
        ),
      ),
    );
  }
}
