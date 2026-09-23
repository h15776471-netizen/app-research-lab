import 'package:flutter/material.dart';

import '../theme/app_radii.dart';

/// A thin wrapper around [Card] using the centrally-defined CardTheme
/// (border, radius 12, elevation 0 — see AppTheme). Feature widgets
/// compose from this instead of redeclaring border/radius/elevation.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap});

  final Widget child;

  /// SAWA-specific rule (Design Handoff §16): the whole ProviderCard is a
  /// single tap target — no separate button inside it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(child: child);
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: card,
    );
  }
}
