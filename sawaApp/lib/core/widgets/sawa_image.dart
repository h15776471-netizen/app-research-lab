import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'category_icon.dart';

/// Shows a provider image from a bundled asset (`assets/...`, extracted from
/// the source catalogs) or a network URL (Storage uploads).
///
/// When there is no genuine image, a branded SAWA placeholder is shown —
/// never a random stock photo, never a catalog page render.
class SawaImage extends StatelessWidget {
  const SawaImage({
    super.key,
    required this.url,
    this.categoryId,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String? url;
  final String? categoryId;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return BrandedPlaceholder(categoryId: categoryId);
    Widget error(BuildContext _, Object __, [Object? ___]) => BrandedPlaceholder(categoryId: categoryId);
    if (u.startsWith('assets/')) {
      return Image.asset(
        u,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (c, e, s) => error(c, e),
      );
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      placeholder: (_, __) => const ColoredBox(color: AppColors.accentLight),
      errorWidget: (c, _, e) => error(c, e),
    );
  }
}

/// Elegant, clearly-not-a-photo placeholder: champagne gradient, the
/// category glyph and a thin gold frame.
class BrandedPlaceholder extends StatelessWidget {
  const BrandedPlaceholder({super.key, this.categoryId, this.compact = false});

  final String? categoryId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'لا توجد صورة من المزود بعد',
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.gradientChampagne),
        child: LayoutBuilder(builder: (context, c) {
          final size = (c.biggest.shortestSide * 0.28).clamp(18.0, 56.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 6 : 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(compact ? 8 : 12),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon(categoryId), size: size, color: AppColors.accent),
                    if (!compact && c.maxHeight > 120) ...[
                      const SizedBox(height: 8),
                      Text(
                        'SAWA',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
