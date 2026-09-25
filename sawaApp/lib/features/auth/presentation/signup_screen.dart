import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/account_models.dart';
import 'auth_scaffold.dart';

/// Sign-up with role selection. The role is sent as sign-up metadata and
/// written by the database trigger (customer | provider only).
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.initialProvider = false});

  final bool initialProvider;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late UserRole _role = widget.initialProvider ? UserRole.provider : UserRole.customer;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authNotifierProvider.notifier).clearMessages());
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authNotifierProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          role: _role,
          phone: _phone.text.trim().isEmpty ? null : normalizePhone(_phone.text),
        );
    if (!ok || !mounted) return;
    context.go(_role == UserRole.provider ? '/p/onboarding' : '/c/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    return AuthScaffold(
      title: 'إنشاء حساب جديد',
      subtitle: 'اختر نوع حسابك — يمكنك التصفح وإرسال الطلبات بدون حساب أيضاً.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (auth.error != null) FormMessage(text: auth.error!),
          if (auth.info != null) FormMessage(text: auth.info!, isError: false),
          Text('نوع الحساب', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          AppSelectCard(
            label: 'أبحث عن خدمات لمناسبتي',
            subtitle: 'أتصفح المزودين وأخطط وأتابع طلباتي',
            icon: Icons.celebration_outlined,
            isSelected: _role == UserRole.customer,
            onTap: () => setState(() => _role = UserRole.customer),
          ),
          const SizedBox(height: 10),
          AppSelectCard(
            label: 'أنا مزود خدمة',
            subtitle: 'قاعة، تصوير، ورد وغيرها — أدير ملفي التجاري وخدماتي',
            icon: Icons.storefront_outlined,
            isSelected: _role == UserRole.provider,
            onTap: () => setState(() => _role = UserRole.provider),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _role == UserRole.provider ? 'اسمك (صاحب الحساب)' : 'الاسم',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'يرجى كتابة الاسم';
              if (t.length > 120) return 'الاسم طويل جداً';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف (اختياري)',
              hintText: '07XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty || isValidPhone(v)) ? null : 'رقم الهاتف غير صحيح',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline)),
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              helperText: '8 أحرف على الأقل',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل' : null,
          ),
          const SizedBox(height: 22),
          AppPrimaryButton(
            label: _role == UserRole.provider ? 'إنشاء حساب مزود' : 'إنشاء الحساب',
            isLoading: auth.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.pushReplacementNamed(AppRoute.login),
            child: const Text('لديك حساب؟ سجّل الدخول'),
          ),
        ]),
      ),
    );
  }
}
