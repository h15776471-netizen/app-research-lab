import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Cairo typography scale — Design Handoff §6/§25. line-height 1.4x
/// throughout (prevents Arabic glyph collision across wrapped lines).
abstract final class AppTextStyles {
  static TextStyle get h1 => GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => GoogleFonts.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );
}
