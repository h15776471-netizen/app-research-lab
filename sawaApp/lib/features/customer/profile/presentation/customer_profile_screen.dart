import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حسابي'),
        automaticallyImplyLeading: false,
      ),
      body: authState.isAuthenticated
          ? _ProfileContent(
              displayName: authState.user?.displayName ?? '',
              email: authState.user?.email ?? '',
              onSignOut: () => ref.read(authNotifierProvider.notifier).signOut(),
            )
          : _GuestState(),
    );
  }
}

class _GuestState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outlined,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('زائر', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'سجّل دخولك للوصول لحسابك الكامل',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 220,
              child: AppPrimaryButton(
                label: 'تسجيل الدخول',
                onPressed: () => context.goNamed(AppRoute.login),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: 220,
              child: AppSecondaryButton(
                label: 'إنشاء حساب',
                onPressed: () => context.goNamed(AppRoute.signup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.displayName,
    required this.email,
    required this.onSignOut,
  });

  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Avatar
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.primary,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(displayName, style: AppTextStyles.h2),
        ),
        Center(
          child: Text(
            email,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Menu items
        _ProfileMenuItem(
          icon: Icons.inbox_outlined,
          label: 'طلباتي',
          onTap: () => context.goNamed(AppRoute.myRequests),
        ),
        _ProfileMenuItem(
          icon: Icons.event_note_outlined,
          label: 'مناسباتي',
          onTap: () => context.goNamed(AppRoute.eventPlanner),
        ),

        const Divider(color: AppColors.border, height: AppSpacing.xxl),

        _ProfileMenuItem(
          icon: Icons.logout,
          label: 'تسجيل الخروج',
          onTap: onSignOut,
          destructive: true,
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
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
