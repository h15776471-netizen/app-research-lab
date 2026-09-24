import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary — Deep Burgundy ─────────────────────────────────────────────
  static const primary = Color(0xFF7B1D3E);
  static const primaryLight = Color(0xFFF5E6ED);
  static const primaryMid = Color(0xFFC4607F);
  static const onPrimary = Color(0xFFFFFFFF);

  // ── Accent — Champagne Gold ─────────────────────────────────────────────
  static const accent = Color(0xFFBD9358);
  static const accentLight = Color(0xFFF5E6C8);

  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const background = Color(0xFFFAF5F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFDF8F4);

  // ── Text ────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1A0810);
  static const textSecondary = Color(0xFF7A5268);
  static const textHint = Color(0xFFBFA8B4);

  // ── Borders ─────────────────────────────────────────────────────────────
  static const border = Color(0xFFEAD0DC);
  static const borderLight = Color(0xFFF5E8EF);

  // ── Semantic ────────────────────────────────────────────────────────────
  static const success = Color(0xFF2D7A52);
  static const successLight = Color(0xFFE5F4EC);
  static const error = Color(0xFFB32A2A);
  static const errorLight = Color(0xFFFDEDED);
  static const warning = Color(0xFFC5862B);
  static const warningLight = Color(0xFFFEF0DC);

  // ── Badge ────────────────────────────────────────────────────────────────
  static const reviewedBadgeIcon = primary;

  // ── Gradients ───────────────────────────────────────────────────────────
  static const gradientHero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4A0E22), Color(0xFF7B1D3E)],
  );

  static const gradientCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC1A0810)],
  );
}
