import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Hero section
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'sawa',
                      style: AppTextStyles.display.copyWith(
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'خلّي مناسبتك\nتبدأ من هنا.',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'اكتشف أفضل خدمات المناسبات في بغداد',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Action panel
            Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPrimaryButton(
                    label: 'إنشاء حساب',
                    onPressed: () => context.goNamed(AppRoute.signup),
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    label: 'تسجيل الدخول',
                    onPressed: () => context.goNamed(AppRoute.login),
                  ),
                  const SizedBox(height: 16),
                  const _Divider(),
                  const SizedBox(height: 16),
                  _BrowseButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('أو', style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _BrowseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.goNamed(AppRoute.customerHome),
      child: Text(
        'تصفح بدون تسجيل',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
