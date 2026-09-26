import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/errors.dart';
import '../../../data/data_providers.dart';
import 'sawa_wordmark.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(authRepositoryProvider).isAvailable;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.gradientHero),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 24),
                  const SawaWordmark(light: true, size: 48),
                  const SizedBox(height: 40),
                  Text(
                    'خلّي مناسبتك\nتبدأ من هنا.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display.copyWith(color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'قاعات، تصوير، ورد وخدمات مناسبات في بغداد — بمعلومات منظمة وواضحة.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(54),
                      textStyle: AppTextStyles.button,
                    ),
                    onPressed: () => context.pushNamed(AppRoute.signup),
                    child: const Text('إنشاء حساب'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    onPressed: () => context.pushNamed(AppRoute.login),
                    child: const Text('تسجيل الدخول'),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('أو', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                  ]),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.champagne),
                    onPressed: () => context.goNamed(AppRoute.customerHome),
                    child: const Text('تصفح بدون تسجيل'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    onPressed: () => context.pushNamed(AppRoute.signup, queryParameters: {'role': 'provider'}),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('صاحب قاعة أو مصور أو محل ورد؟ انضم كمزود خدمة'),
                  ),
                  if (!online) ...[
                    const SizedBox(height: 16),
                    Text(
                      offlineMessage,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: Colors.white60),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
