import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/data_providers.dart';
import 'provider_browser.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    final count = ref.watch(categoryCountsProvider)[categoryId] ?? 0;
    final pad = pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(category?.nameAr ?? ''),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/c/home')),
      ),
      body: ProviderBrowser(
        fixedCategoryId: categoryId,
        header: ContentFrame(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 0),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                child: Icon(categoryIcon(categoryId), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(category?.nameAr ?? '', style: AppTextStyles.h2),
                  Text(
                    count == 0 ? 'لا مزودين منشورين بعد' : '$count مزود في بغداد · بيانات من مصادر المزودين',
                    style: AppTextStyles.caption,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
