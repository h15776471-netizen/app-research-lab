import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/provider_category.dart';
import '../state/providers_list_notifier.dart';
import 'provider_card.dart';

/// Displays all providers belonging to [category] in a scrollable
/// ListView.builder. Handles loading / error / empty states explicitly —
/// never a blank screen (Master Spec §13 Screen 2 / Skill Module 9).
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.category});

  final ProviderCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProviders = ref.watch(providersByCategoryProvider(category));

    return Scaffold(
      appBar: AppBar(title: Text(category.labelAr)),
      body: asyncProviders.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          onRetry: () => ref.invalidate(providersByCategoryProvider(category)),
        ),
        data: (providers) {
          if (providers.isEmpty) {
            return const EmptyStateView(message: AppStrings.categoryEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < providers.length - 1 ? AppSpacing.md : 0,
                ),
                child: ProviderCard(provider: providers[index]),
              );
            },
          );
        },
      ),
    );
  }
}
