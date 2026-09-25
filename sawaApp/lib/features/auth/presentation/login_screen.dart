import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  /// Customer path to return to after signing in (e.g. /c/requests).
  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authNotifierProvider.notifier).clearMessages());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authNotifierProvider.notifier).signIn(email: _email.text, password: _password.text);
    if (!ok || !mounted) return;
    final auth = ref.read(authNotifierProvider);
    final back = widget.returnTo;
    if (!auth.isProvider && back != null && back.startsWith('/c/')) {
      context.go(back);
    } else {
      context.go(auth.isProvider ? '/p/dashboard' : '/c/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    return AuthScaffold(
      title: 'أهلاً بعودتك',
      subtitle: 'سجّل الدخول لمتابعة طلباتك أو إدارة نشاطك التجاري.',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (auth.error != null) FormMessage(text: auth.error!),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'إظهار' : 'إخفاء',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور' : null,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.pushNamed(AppRoute.forgotPassword),
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ),
            const SizedBox(height: 8),
            AppPrimaryButton(label: 'تسجيل الدخول', isLoading: auth.isLoading, onPressed: _submit),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pushReplacementNamed(AppRoute.signup),
              child: const Text('ليس لديك حساب؟ أنشئ حساباً'),
            ),
          ]),
        ),
      ),
    );
  }
}
