import 'package:flutter/material.dart';

/// SAWA design tokens — "Organized Notebook" direction.
///
/// Source: sawa-design-system-ux-handoff.md §5/§25, cross-checked against
/// SAWA_FINAL_MASTER_SPEC.md §17. The two agree on every value here except
/// the badge-icon color, which the Master Spec's Phase 20 audit corrected
/// (see [reviewedBadgeIcon]).
abstract final class AppColors {
  static const primary = Color(0xFFB5654A);

  /// Borders/fills ONLY — never a standalone icon or text color.
  /// (~2:1 contrast against light surfaces, below the 3:1 minimum for
  /// meaningful UI graphics — Master Spec Phase 4/20.)
  static const secondary = Color(0xFFD9A05B);

  static const background = Color(0xFFFBF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2B2320);
  static const textSecondary = Color(0xFF6B5F58);
  static const border = Color(0xFFE4D9CF);
  static const success = Color(0xFF4C7A5E);
  static const error = Color(0xFFB3442F);

  /// Reserved, unused in this MVP (no warning-state screens exist).
  static const warning = Color(0xFFC48A3F);

  /// "تمت مراجعته من فريق sawa" badge icon color.
  ///
  /// Master Spec §Phase 20 fix: render this icon in [textSecondary] (or
  /// [primary]), never in [secondary] — the badge carries the project's
  /// core trust claim and must not be the least legible element on the
  /// card.
  static const reviewedBadgeIcon = textSecondary;
}
