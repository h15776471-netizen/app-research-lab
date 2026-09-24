import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        automaticallyImplyLeading: false,
      ),
      body: authState.isAuthenticated
          ? _DashboardContent(
              displayName: authState.user?.displayName ?? 'مزود الخدمة',
            )
          : _NotAuthenticatedState(),
    );
  }
}

class _NotAuthenticatedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.lg),
            Text('تسجيل الدخول مطلوب', style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 220,
              child: AppPrimaryButton(
                label: 'تسجيل الدخول',
                onPressed: () => context.goNamed(AppRoute.login),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Greeting
        Text(
          'أهلاً، $displayName',
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'هذه لمحة عامة عن نشاطك',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Stats row — no fake numbers, show 0 until real data exists
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'الطلبات',
                value: '0',
                icon: Icons.inbox_outlined,
                hint: 'لا توجد طلبات بعد',
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: 'الخدمات',
                value: '0',
                icon: Icons.design_services_outlined,
                hint: 'لم تُضف خدمات بعد',
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        const Divider(color: AppColors.border),
        const SizedBox(height: AppSpacing.xl),

        // Quick actions
        Text('إجراءات سريعة', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),
        AppPrimaryButton(
          label: 'إضافة خدمة جديدة',
          icon: Icons.add,
          onPressed: () => context.goNamed(AppRoute.addService),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'تصفح الطلبات',
          onPressed: () => context.goNamed(AppRoute.providerRequests),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Onboarding nudge if no services
        _OnboardingNudge(
          onTap: () => context.goNamed(AppRoute.providerOnboarding),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const Spacer(),
              Text(
                value,
                style: AppTextStyles.h1.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: AppTextStyles.h3),
          const SizedBox(height: 2),
          Text(hint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _OnboardingNudge extends StatelessWidget {
  const _OnboardingNudge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.tips_and_updates_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أكمل ملفك الشخصي', style: AppTextStyles.h3),
                  Text(
                    'ستظهر للمزيد من العملاء عند اكتمال ملفك',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 14),
          ],
        ),
      ),
    );
  }
}
