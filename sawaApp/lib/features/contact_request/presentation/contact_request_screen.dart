import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/sawa_image.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/data_providers.dart';
import '../state/contact_request_notifier.dart';

/// Guest-friendly contact request: name + phone (+ optional message).
/// Signed-in customers are linked automatically by the server.
class ContactRequestScreen extends ConsumerStatefulWidget {
  const ContactRequestScreen({super.key, required this.providerId, this.serviceId, this.packageTitle});

  final String providerId;
  final String? serviceId;
  final String? packageTitle;

  @override
  ConsumerState<ContactRequestScreen> createState() => _ContactRequestScreenState();
}

class _ContactRequestScreenState extends ConsumerState<ContactRequestScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _name = TextEditingController(text: user?.fullName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _message = TextEditingController(
      text: widget.packageTitle == null ? '' : 'أرغب بالاستفسار عن: ${widget.packageTitle}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit(String providerId) {
    if (!_form.currentState!.validate()) return;
    ref.read(contactSubmitProvider.notifier).submit(
          providerId: providerId,
          name: _name.text,
          contact: normalizePhone(_phone.text),
          message: _message.text,
          serviceId: widget.serviceId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final providerAsync = ref.watch(providerByIdProvider(widget.providerId));
    final submit = ref.watch(contactSubmitProvider);
    final online = ref.watch(requestsRepositoryProvider).isAvailable;
    final user = ref.watch(authNotifierProvider).user;

    ref.listen(contactSubmitProvider, (_, next) {
      if (next is ContactSubmitted) {
        context.pushReplacementNamed(AppRoute.contactSuccess, queryParameters: {'ref': next.referenceCode});
      }
    });

    final provider = providerAsync.valueOrNull;
    final service = provider?.services.where((s) => s.id == widget.serviceId).firstOrNull;
    final busy = submit is ContactSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('طلب تواصل')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (provider != null)
                    SurfaceCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: SawaImage(url: provider.cardImageUrl, categoryId: provider.categoryId),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(provider.businessName, style: AppTextStyles.h3),
                            if (service != null)
                              Text('بخصوص: ${service.name}', style: AppTextStyles.caption)
                            else if (widget.packageTitle != null)
                              Text('بخصوص: ${widget.packageTitle}', style: AppTextStyles.caption),
                          ]),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  const InfoBanner(
                    icon: Icons.support_agent_outlined,
                    message:
                        'يصل طلبك إلى فريق SAWA أولاً — نتابعه ونساعدك بالتواصل مع المزود. رقمك لا يظهر لأي أحد آخر.',
                  ),
                  if (!online) ...[
                    const SizedBox(height: 12),
                    const InfoBanner(icon: Icons.cloud_off_outlined, color: AppColors.warning, message: offlineMessage),
                  ],
                  const SizedBox(height: 20),
                  if (submit is ContactFailed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                            child:
                                Text(submit.message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
                      ]),
                    ),
                  TextFormField(
                    controller: _name,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'يرجى كتابة الاسم';
                      if (t.length > 100) return 'الاسم طويل جداً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف أو واتساب',
                      hintText: '07XXXXXXXXX',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال رقم للتواصل';
                      if (!isValidPhone(v)) return 'رقم الهاتف غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _message,
                    enabled: !busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'رسالتك (اختياري)',
                      hintText: 'مثلاً: تاريخ المناسبة، عدد الضيوف، أسئلتك…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: 'إرسال الطلب',
                    icon: Icons.send_outlined,
                    isLoading: busy,
                    onPressed: (provider == null || !online) ? null : () => _submit(provider.id),
                  ),
                  if (user == null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'لا تحتاج حساباً. إذا سجّلت الدخول، يظهر الطلب في «طلباتي» مع حالته.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
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
