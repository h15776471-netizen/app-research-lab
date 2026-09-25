import 'package:flutter/material.dart';

/// SAWA Premium palette — Luxury Iraqi Event Platform.
///
/// Ivory / warm white / charcoal carry the interface. Burgundy (wine) is the
/// accent for hierarchy and primary actions only — never a fill for whole
/// screens. Champagne and muted gold are used sparingly for highlights.
abstract final class AppColors {
  // ── Wine (primary accent) ───────────────────────────────────────────────
  static const primary = Color(0xFF6E1E33);
  static const primaryDark = Color(0xFF4B1222);
  static const primaryLight = Color(0xFFF5ECEE); // soft wine tint for selections
  static const primaryMid = Color(0xFFA0465E);
  static const onPrimary = Color(0xFFFFFFFF);

  // ── Champagne & muted gold ─────────────────────────────────────────────
  static const accent = Color(0xFFB08D57); // muted gold
  static const accentLight = Color(0xFFF4ECDD); // champagne
  static const champagne = Color(0xFFE8D8BD);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const background = Color(0xFFFAF7F2); // ivory
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFFCF7); // warm white
  static const charcoal = Color(0xFF221C1B);

  // ── Text ───────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF221C1B);
  static const textSecondary = Color(0xFF6E6461);
  static const textHint = Color(0xFFA59B95);

  // ── Borders ────────────────────────────────────────────────────────────
  static const border = Color(0xFFE8E1D8);
  static const borderLight = Color(0xFFF1ECE5);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const success = Color(0xFF2F6B4F);
  static const successLight = Color(0xFFE6F2EB);
  static const error = Color(0xFFA8322D);
  static const errorLight = Color(0xFFFBECEA);
  static const warning = Color(0xFF9A6A1F);
  static const warningLight = Color(0xFFFBF1DF);
  static const info = Color(0xFF3F5A73);
  static const infoLight = Color(0xFFEAF0F5);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const gradientHero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF2A1A1C), Color(0xFF4B1222), Color(0xFF6E1E33)],
  );

  static const gradientChampagne = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFFFCF7), Color(0xFFF4ECDD)],
  );

  /// Legibility scrim for text over photos.
  static const gradientCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB3160E0F)],
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF3B2A25).withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get liftShadow => [
        BoxShadow(
          color: const Color(0xFF3B2A25).withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 14),
        ),
      ];
}
