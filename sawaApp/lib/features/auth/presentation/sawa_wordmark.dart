import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// "sawa" wordmark with the Arabic "سوا" beneath — typographic, no logo file.
class SawaWordmark extends StatelessWidget {
  const SawaWordmark({super.key, this.light = false, this.size = 34});

  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final main = light ? Colors.white : AppColors.primary;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        'sawa',
        style: GoogleFonts.cairo(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: size * 0.06,
          color: main,
          height: 1,
        ),
      ),
      const SizedBox(height: 6),
      Container(width: size * 0.9, height: 1.5, color: AppColors.accent),
      const SizedBox(height: 6),
      Text(
        'سوا · للمناسبات',
        style: GoogleFonts.cairo(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w500,
          color: light ? AppColors.champagne : AppColors.accent,
        ),
      ),
    ]);
  }
}
