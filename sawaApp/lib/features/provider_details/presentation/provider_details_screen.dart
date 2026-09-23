import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../providers_list/data/provider_model.dart';
import '../../providers_list/state/providers_list_notifier.dart';

/// Provider details: image gallery → info → badge → Instagram link →
/// sticky "طلب تواصل" CTA.
///
/// The sticky bottom button is the single most important UX decision in
/// this screen (Master Spec §13 D5: "أهم قرار UX في كامل التطبيق").
class ProviderDetailsScreen extends ConsumerWidget {
  const ProviderDetailsScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProvider = ref.watch(providerByIdProvider(providerId));

    return asyncProvider.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المزوّد')),
        body: const LoadingView(),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المزوّد')),
        body: ErrorView(
          onRetry: () => ref.invalidate(providerByIdProvider(providerId)),
        ),
      ),
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل المزوّد')),
            body: const EmptyStateView(message: 'المزوّد غير موجود.'),
          );
        }
        return _ProviderDetailsView(provider: provider);
      },
    );
  }
}

class _ProviderDetailsView extends StatelessWidget {
  const _ProviderDetailsView({required this.provider});

  final SawaProvider provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(provider.name)),
      // Sticky bottom CTA — locked UX requirement D5.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: AppPrimaryButton(
            label: 'طلب تواصل',
            onPressed: () => context.goNamed(
              AppRoute.contactRequest,
              pathParameters: {'providerId': provider.id},
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImageGallery(images: provider.images),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.name, style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    provider.category.labelAr,
                    style: AppTextStyles.bodySmall,
                  ),
                  if (provider.shortDescription != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      provider.shortDescription!,
                      style: AppTextStyles.body,
                    ),
                  ],
                  if (provider.priceRangeText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      provider.priceRangeText!,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: AppSpacing.lg),
                  _ReviewedSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _InstagramButton(instagramUrl: provider.instagramUrl),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Image.asset(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const ColoredBox(
              color: AppColors.border,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textSecondary,
                  size: 40,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewedSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 20,
          color: AppColors.reviewedBadgeIcon,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          AppStrings.reviewedBadge,
          style: AppTextStyles.body.copyWith(
            color: AppColors.reviewedBadgeIcon,
          ),
        ),
      ],
    );
  }
}

class _InstagramButton extends StatelessWidget {
  const _InstagramButton({required this.instagramUrl});

  final String instagramUrl;

  Future<void> _openInstagram(BuildContext context) async {
    try {
      final uri = Uri.parse(instagramUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $instagramUrl');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.instagramLinkFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openInstagram(context),
        icon: const Icon(Icons.open_in_new, size: 20),
        label: const Text('تصفّح على Instagram'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
    );
  }
}
