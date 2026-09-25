import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(authNotifierProvider.notifier).sendPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _sent = err == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'استعادة كلمة المرور',
      subtitle: 'اكتب بريدك وسنرسل لك رابطاً لتعيين كلمة مرور جديدة.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null) FormMessage(text: _error!),
          if (_sent)
            const FormMessage(text: 'إذا كان البريد مسجّلاً، سيصلك رابط الاستعادة خلال دقائق.', isError: false),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline)),
            validator: validateEmail,
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(label: 'إرسال الرابط', isLoading: _busy, onPressed: _submit),
        ]),
      ),
    );
  }
}
