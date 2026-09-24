import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers_list/data/provider_category.dart';
import '../../../providers_list/data/provider_model.dart';
import '../../../providers_list/state/providers_list_notifier.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final allProviders = ref.watch(allProvidersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _HeroSliver(
            isAuthenticated: authState.isAuthenticated,
            displayName: authState.user?.displayName,
          ),
          SliverToBoxAdapter(
            child: _EventPlannerBanner(
              onTap: () => context.goNamed(AppRoute.eventPlanner),
            ),
          ),
          const SliverToBoxAdapter(child: _CategoriesSection()),
          SliverToBoxAdapter(
            child: allProviders.when(
              data: (providers) => _FeaturedSection(providers: providers),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section)),
        ],
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _HeroSliver extends StatelessWidget {
  const _HeroSliver({required this.isAuthenticated, this.displayName});

  final bool isAuthenticated;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientHero),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          MediaQuery.of(context).padding.top + AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuthenticated && displayName != null
                            ? 'أهلاً، $displayName'
                            : 'أهلاً بيك في sawa',
                        style: AppTextStyles.h3.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'خلّي مناسبتك\nتبدأ من هنا.',
                        style: AppTextStyles.display.copyWith(
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'اكتشف أفضل خدمات المناسبات في بغداد',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event Planner Banner ──────────────────────────────────────────────────────

class _EventPlannerBanner extends StatelessWidget {
  const _EventPlannerBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFBD9358), Color(0xFF9B7640)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_note, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'خطّط مناسبتك',
                        style: AppTextStyles.h3.copyWith(color: Colors.white),
                      ),
                      Text(
                        'أخبرنا عن مناسبتك ونوصّلك بالمزودين',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Categories ────────────────────────────────────────────────────────────────

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  static const _categories = [
    _CategoryItem(
      category: ProviderCategory.hall,
      icon: Icons.business,
      emoji: '🏛️',
    ),
    _CategoryItem(
      category: ProviderCategory.photography,
      icon: Icons.camera_alt,
      emoji: '📸',
    ),
    _CategoryItem(
      category: ProviderCategory.decor,
      icon: Icons.auto_awesome,
      emoji: '✨',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الفئات', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: _categories
                .map((c) => Expanded(child: _CategoryTile(item: c)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.category,
    required this.icon,
    required this.emoji,
  });
  final ProviderCategory category;
  final IconData icon;
  final String emoji;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.item});

  final _CategoryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.goNamed(
            AppRoute.category,
            pathParameters: {'categoryId': item.category.id},
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.category.labelAr,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Featured Section ─────────────────────────────────────────────────────────

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({required this.providers});

  final List<SawaProvider> providers;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    // Show up to 6 providers as a curated list
    final featured = providers.take(6).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('مزودون مميزون', style: AppTextStyles.h2)),
              TextButton(
                onPressed: () => context.goNamed(AppRoute.explore),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => _FeaturedCard(provider: featured[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.provider});

  final SawaProvider provider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed(
        AppRoute.providerDetails,
        pathParameters: {'providerId': provider.id},
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.primaryLight,
                    child: const Icon(
                      Icons.photo,
                      color: AppColors.primaryMid,
                      size: 40,
                    ),
                  ),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientCard,
                    ),
                  ),
                  // Reviewed badge
                  if (provider.reviewedBySawa)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'تمت المراجعة',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (provider.priceRangeText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      provider.priceRangeText!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    provider.category.labelAr,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
