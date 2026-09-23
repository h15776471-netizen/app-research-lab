import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../data/provider_model.dart';

/// Full-width provider card — used in CategoryScreen (Design Handoff §16).
///
/// Layout: 4:3 image → name → optional description → optional price range →
/// "reviewed by sawa" badge. The entire card is a single tap target that
/// navigates to ProviderDetailsScreen (no separate button inside the card).
class ProviderCard extends StatelessWidget {
  const ProviderCard({super.key, required this.provider});

  final SawaProvider provider;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.goNamed(
        AppRoute.providerDetails,
        pathParameters: {'providerId': provider.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProviderImage(imagePath: provider.images.first),
          _ProviderInfo(provider: provider),
        ],
      ),
    );
  }
}

class _ProviderImage extends StatelessWidget {
  const _ProviderImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const ColoredBox(
            color: AppColors.border,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondary,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderInfo extends StatelessWidget {
  const _ProviderInfo({required this.provider});

  final SawaProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(provider.name, style: AppTextStyles.h2),
          if (provider.shortDescription != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              provider.shortDescription!,
              style: AppTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (provider.priceRangeText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              provider.priceRangeText!,
              style: AppTextStyles.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const _ReviewedBadge(),
        ],
      ),
    );
  }
}

/// "تمت مراجعته من فريق sawa" badge — icon in [AppColors.reviewedBadgeIcon]
/// (textSecondary, ≥4.5:1 contrast) per Master Spec Phase 20 fix.
/// Never rendered with the secondary color (#D9A05B) which falls below the
/// 3:1 minimum for meaningful UI graphics.
class _ReviewedBadge extends StatelessWidget {
  const _ReviewedBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 16,
          color: AppColors.reviewedBadgeIcon,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          AppStrings.reviewedBadge,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.reviewedBadgeIcon,
          ),
        ),
      ],
    );
  }
}
