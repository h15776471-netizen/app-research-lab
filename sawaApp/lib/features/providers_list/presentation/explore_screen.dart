import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/provider_category.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const _items = [
    _ExploreItem(
      category: ProviderCategory.hall,
      emoji: '🏛️',
      description: 'قاعات الأفراح والمناسبات',
    ),
    _ExploreItem(
      category: ProviderCategory.photography,
      emoji: '📸',
      description: 'مصورون محترفون للمناسبات',
    ),
    _ExploreItem(
      category: ProviderCategory.decor,
      emoji: '✨',
      description: 'تزيين وديكور المناسبات',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('اكتشف'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الفئات',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'اختر فئة للعثور على أفضل مزودي الخدمة',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) => _CategoryCard(item: _items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreItem {
  const _ExploreItem({
    required this.category,
    required this.emoji,
    required this.description,
  });
  final ProviderCategory category;
  final String emoji;
  final String description;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item});

  final _ExploreItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.goNamed(
          AppRoute.category,
          pathParameters: {'categoryId': item.category.id},
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.labelAr,
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textHint,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
