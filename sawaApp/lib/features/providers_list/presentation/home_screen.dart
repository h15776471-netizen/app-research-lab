import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/provider_category.dart';

/// PHASE 1 PLACEHOLDER: proves navigation + category enum wiring only.
/// The real CategoryTile component (Design Handoff §14, Skill Module 4)
/// is built in Phase 3, styled per AppCard/AppTheme, not this inline tile.
///
/// Component responsibility (Skill Module 4): Home shows CATEGORIES, not
/// individual providers — do not turn this into a provider list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sawa')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.homeWelcome),
              const SizedBox(height: AppSpacing.lg),
              for (final category in ProviderCategory.values) ...[
                _CategoryTilePlaceholder(category: category),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTilePlaceholder extends StatelessWidget {
  const _CategoryTilePlaceholder({required this.category});

  final ProviderCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(category.labelAr),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => context.goNamed(
          AppRoute.category,
          pathParameters: {'categoryId': category.id},
        ),
      ),
    );
  }
}
