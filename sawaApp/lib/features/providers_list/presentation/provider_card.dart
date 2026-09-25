import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/sawa_image.dart';
import '../../../core/widgets/ui.dart' show Pressable, Breakpoints;
import '../../../data/models/catalog_models.dart';

/// Provider card: real image (or branded placeholder), name, category,
/// location, honest price label. No badges that the data cannot support.
class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.provider,
    required this.onTap,
    this.categoryName,
    this.now,
  });

  final SawaProvider provider;
  final VoidCallback onTap;
  final String? categoryName;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final price = p.displayPrice(now ?? DateTime.now());
    final location = [p.area, p.city].whereType<String>().toSet().join(' · ');
    return Pressable(
      onTap: onTap,
      semanticLabel: p.businessName,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(fit: StackFit.expand, children: [
              Hero(
                tag: 'provider-image-${p.id}',
                child: SawaImage(url: p.cardImageUrl, categoryId: p.categoryId, semanticLabel: p.businessName),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 70,
                child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.gradientCard)),
              ),
              if (categoryName != null)
                PositionedDirectional(
                  top: 10,
                  start: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(categoryIcon(p.categoryId), size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(categoryName!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              if (price != null && price.isOffer)
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration:
                        BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadii.full)),
                    child: Text('عرض',
                        style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (p.capacity != null)
                PositionedDirectional(
                  bottom: 10,
                  start: 10,
                  child: Row(children: [
                    const Icon(Icons.groups_outlined, size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${p.capacity} ضيف',
                        style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (p.galleryImages.length > 1)
                PositionedDirectional(
                  bottom: 10,
                  end: 10,
                  child: Row(children: [
                    const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${p.galleryImages.length}', style: AppTextStyles.caption.copyWith(color: Colors.white)),
                  ]),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.businessName, style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location.isEmpty ? 'بغداد' : location,
                      style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
              if (p.shortDescription != null) ...[
                const SizedBox(height: 8),
                Text(p.shortDescription!, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              if (price != null)
                Text(
                  displayPriceLabel(price),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text('السعر عند الطلب', style: AppTextStyles.caption),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Responsive grid of provider cards.
class ProviderGrid extends StatelessWidget {
  const ProviderGrid({super.key, required this.providers, required this.onTap, this.categoryNames = const {}});

  final List<SawaProvider> providers;
  final void Function(SawaProvider) onTap;
  final Map<String, String> categoryNames;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, c) {
      final cols = Breakpoints.cardColumns(c.crossAxisExtent);
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: _cardHeight(c.crossAxisExtent, cols),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => ProviderCard(
            provider: providers[i],
            categoryName: categoryNames[providers[i].categoryId],
            onTap: () => onTap(providers[i]),
          ),
          childCount: providers.length,
        ),
      );
    });
  }

  static double _cardHeight(double width, int cols) {
    final cardWidth = (width - (cols - 1) * 16) / cols;
    return cardWidth * 3 / 4 + 150;
  }
}
