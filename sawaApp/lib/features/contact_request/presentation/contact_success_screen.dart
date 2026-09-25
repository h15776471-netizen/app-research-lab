import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/ui.dart';

/// Real confirmation: shown only after the server returned a reference.
class ContactSuccessScreen extends ConsumerWidget {
  const ContactSuccessScreen({super.key, this.reference, this.kind = 'contact'});

  final String? reference;

  /// 'contact' (provider request) or 'inquiry' (planner).
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authNotifierProvider).isAuthenticated;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 48, color: AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  kind == 'inquiry' ? 'وصل طلب التخطيط' : 'وصل طلبك',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1,
                ),
                const SizedBox(height: 8),
                Text(
                  'نتابع طلبك ونساعدك بالتواصل مع المزوّد. فريقنا بيتواصل وياك.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                if (reference != null) ...[
                  const SizedBox(height: 24),
                  SurfaceCard(
                    color: AppColors.surfaceWarm,
                    child: Column(children: [
                      Text('الرقم المرجعي', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      SelectableText(reference!,
                          style: AppTextStyles.h1.copyWith(letterSpacing: 2, color: AppColors.primary)),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: reference!));
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('تم نسخ الرقم المرجعي')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ'),
                      ),
                      Text('احتفظ به إذا تواصلت مع فريق SAWA.', style: AppTextStyles.caption),
                    ]),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(52)),
                  onPressed: () => context.go(signedIn ? '/c/requests' : '/c/home'),
                  child: Text(signedIn ? 'متابعة طلباتي' : 'العودة للرئيسية'),
                ),
                if (!signedIn) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('أنشئ حساباً لمتابعة طلباتك القادمة'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
