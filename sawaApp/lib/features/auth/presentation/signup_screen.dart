import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  UserRole _role = UserRole.customer;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _email.text.trim().contains('@') &&
      _password.text.trim().length >= 6;

  @override
  void initState() {
    super.initState();
    _name.addListener(_rebuild);
    _email.addListener(_rebuild);
    _password.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(authNotifierProvider.notifier).signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
          role: _role,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        leading: BackButton(onPressed: () => context.goNamed(AppRoute.welcome)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('أهلاً بيك في sawa 🎉', style: AppTextStyles.h1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'اختر نوع حسابك وابدأ',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Role selection
            Text('أنت…', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),
            AppSelectCard(
              label: 'أبحث عن خدمات',
              subtitle: 'أنظّم مناسبتي وأبحث عن مزودين',
              emoji: '💍',
              isSelected: _role == UserRole.customer,
              onTap: () => setState(() => _role = UserRole.customer),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSelectCard(
              label: 'أنا مزود خدمة',
              subtitle: 'أعرض خدماتي وأتابع طلبات العملاء',
              emoji: '🏛️',
              isSelected: _role == UserRole.provider,
              onTap: () => setState(() => _role = UserRole.provider),
            ),

            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.xl),

            // Form fields
            TextField(
              controller: _name,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _valid ? _submit() : null,
              decoration: InputDecoration(
                labelText: 'كلمة المرور (6 أحرف على الأقل)',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            if (state.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'إنشاء الحساب',
              isLoading: state.isLoading,
              onPressed: _valid && !state.isLoading ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('عندك حساب؟ ', style: AppTextStyles.bodySmall),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.login),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
