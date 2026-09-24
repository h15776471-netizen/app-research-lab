import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('طلباتي'),
        automaticallyImplyLeading: false,
      ),
      body: authState.isAuthenticated
          ? const _AuthenticatedRequestsList()
          : _UnauthenticatedState(),
    );
  }
}

class _UnauthenticatedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'سجّل دخولك لتتابع طلباتك',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'جميع طلبات التواصل مع المزودين ستظهر هنا',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
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

class _AuthenticatedRequestsList extends ConsumerWidget {
  const _AuthenticatedRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyStateView(
      icon: Icons.inbox_outlined,
      title: 'لا توجد طلبات بعد',
      message: 'عند إرسال طلب تواصل مع أي مزود، سيظهر هنا',
      action: () => context.goNamed(AppRoute.explore),
      actionLabel: 'تصفح المزودين',
    );
  }
}
