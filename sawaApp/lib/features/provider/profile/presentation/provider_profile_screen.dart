import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حسابي'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: const Icon(
                    Icons.store_outlined,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  authState.user?.displayName ?? 'مزود الخدمة',
                  style: AppTextStyles.h2,
                ),
                Text(
                  authState.user?.email ?? '',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Provider badge
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'حساب مزود خدمة',
                  style: AppTextStyles.body.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Menu
          _MenuTile(
            icon: Icons.edit_outlined,
            label: 'تعديل الملف الشخصي',
            onTap: () => context.goNamed(AppRoute.providerOnboarding),
          ),
          _MenuTile(
            icon: Icons.design_services_outlined,
            label: 'إدارة الخدمات',
            onTap: () => context.goNamed(AppRoute.providerServices),
          ),

          const Divider(color: AppColors.border, height: AppSpacing.xxl),

          _MenuTile(
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            onTap: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: color),
                ),
              ),
              if (!destructive)
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textHint,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
