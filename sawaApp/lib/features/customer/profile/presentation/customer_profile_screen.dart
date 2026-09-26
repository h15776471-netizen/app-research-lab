import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    final online = ref.watch(authRepositoryProvider).isAvailable;
    final live = ref.watch(catalogRepositoryProvider).isLive;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ContentFrame(
          maxWidth: 640,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryLight,
                  child: user == null
                      ? const Icon(Icons.person_outline, color: AppColors.primary)
                      : Text(user.displayName.characters.first,
                          style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.displayName ?? 'زائر', style: AppTextStyles.h2),
                    Text(user?.email ?? 'تتصفح بدون حساب',
                        style: AppTextStyles.bodySmall, textDirection: user == null ? null : TextDirection.ltr),
                    if (user?.phone != null)
                      Text(user!.phone!, style: AppTextStyles.caption, textDirection: TextDirection.ltr),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (user == null) ...[
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(52)),
                onPressed: () => context.pushNamed(AppRoute.login, queryParameters: {'from': '/c/profile'}),
                child: const Text('تسجيل الدخول'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => context.pushNamed(AppRoute.signup), child: const Text('إنشاء حساب')),
              if (!online) ...[
                const SizedBox(height: 10),
                const InfoBanner(icon: Icons.cloud_off_outlined, color: AppColors.warning, message: offlineMessage),
              ],
            ] else ...[
              _Tile(
                icon: Icons.edit_outlined,
                title: 'تعديل الاسم ورقم الهاتف',
                onTap: () => _editProfile(context, ref),
              ),
              _Tile(icon: Icons.inbox_outlined, title: 'طلباتي', onTap: () => context.go('/c/requests')),
            ],
            _Tile(
                icon: Icons.event_note_outlined,
                title: 'مخطط المناسبة',
                onTap: () => context.pushNamed(AppRoute.eventPlanner)),
            const SizedBox(height: 16),
            SurfaceCard(
              color: AppColors.surfaceWarm,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('عن بيانات SAWA', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text(
                  'معلومات المزودين مستخرجة من كتالوجاتهم ومنظمة يدوياً. لا نخمّن الأسعار أو المواقع: '
                  'ما لا يذكره المصدر يظهر «غير متوفر»، وما هو ملتبس يظهر «غير مؤكد».',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(live ? 'متصل بخادم SAWA' : 'وضع التصفح دون اتصال (بيانات مضمّنة)', style: AppTextStyles.caption),
              ]),
            ),
            if (user != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/welcome');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authNotifierProvider).user!;
    final name = TextEditingController(text: user.fullName ?? '');
    final phone = TextEditingController(text: user.phone ?? '');
    final form = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('بياناتي', style: AppTextStyles.h2),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'الاسم'),
              validator: (v) => (v?.trim().length ?? 0) > 120 ? 'الاسم طويل جداً' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '07XXXXXXXXX'),
              validator: (v) => (v == null || v.trim().isEmpty || isValidPhone(v)) ? null : 'رقم الهاتف غير صحيح',
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(50)),
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final err = await ref.read(authNotifierProvider.notifier).updateProfile(
                      fullName: name.text,
                      phone: phone.text.trim().isEmpty ? '' : normalizePhone(phone.text),
                    );
                if (!c.mounted) return;
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'تم حفظ بياناتك')));
              },
              child: const Text('حفظ'),
            ),
          ]),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: AppTextStyles.body),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
