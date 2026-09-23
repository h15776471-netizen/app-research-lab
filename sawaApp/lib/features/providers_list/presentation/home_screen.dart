import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/provider_category.dart';

/// Home screen — 3 category entry points, no scroll, no secondary actions.
///
/// Component responsibility (Master Spec §13 Screen 1 / Skill Module 4):
/// Home shows CATEGORIES only. Individual provider cards live in
/// CategoryScreen, never here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sawa')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(AppStrings.homeWelcome),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final category in ProviderCategory.values) ...[
                      Expanded(
                        child: _CategoryTile(category: category),
                      ),
                      if (category != ProviderCategory.values.last)
                        const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final ProviderCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.goNamed(
          AppRoute.category,
          pathParameters: {'categoryId': category.id},
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  _iconFor(category),
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.labelAr,
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _subtitleFor(category),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ProviderCategory cat) => switch (cat) {
        ProviderCategory.hall => Icons.celebration_outlined,
        ProviderCategory.photography => Icons.camera_alt_outlined,
        ProviderCategory.decor => Icons.auto_awesome_outlined,
      };

  String _subtitleFor(ProviderCategory cat) => switch (cat) {
        ProviderCategory.hall => 'قاعات أفراح ومناسبات في بغداد',
        ProviderCategory.photography => 'مصورين أعراس وخطوبة',
        ProviderCategory.decor => 'ديكور وتزيين للمناسبات',
      };
}
