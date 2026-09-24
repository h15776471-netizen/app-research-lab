import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

/// Reachable only after a confirmed Supabase insert (ContactRequestNotifier
/// transitions to isSuccess = true before navigation).
///
/// Locked copy (Master Spec §36 points 2/3 — never alter these strings):
/// - Primary:   "نتابع طلبك ونساعدك بالتواصل مع المزوّد."
/// - Secondary: "فريقنا بيتواصل وياك." — time-neutral, no "قريباً"
class ContactSuccessScreen extends StatelessWidget {
  const ContactSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outlined,
                  color: AppColors.success,
                  size: 64,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.contactFollowUp,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.contactReassurance,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppPrimaryButton(
                  label: 'العودة للرئيسية',
                  onPressed: () => context.goNamed(AppRoute.customerHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
