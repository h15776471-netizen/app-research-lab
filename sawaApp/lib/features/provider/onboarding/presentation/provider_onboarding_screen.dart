import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../../../data/repositories/provider_portal_repository.dart';
import '../../state/portal_providers.dart';
import '../../widgets/portal_widgets.dart';

/// Creates the business (as a draft) on first run; edits it afterwards.
/// Category-specific fields (e.g. capacity for halls) appear only where
/// they apply. Phone numbers go to `provider_private` — never public.
class ProviderOnboardingScreen extends ConsumerWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(providerPortalRepositoryProvider).isAvailable) {
      return Scaffold(appBar: AppBar(), body: const PortalOffline());
    }
    final business = ref.watch(myBusinessProvider);
    final private = ref.watch(myBusinessPrivateProvider);
    final categories = ref.watch(categoriesProvider);
    if (business.isLoading || categories.isLoading || (business.valueOrNull != null && private.isLoading)) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    return _Form(
      existing: business.valueOrNull,
      private: private.valueOrNull,
      categories: categories.valueOrNull ?? const [],
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.existing, required this.private, required this.categories});

  final SawaProvider? existing;
  final ProviderPrivate? private;
  final List<SawaCategory> categories;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late String? _category = widget.existing?.categoryId;
  late final _name = TextEditingController(text: widget.existing?.businessName ?? '');
  late final _short = TextEditingController(text: widget.existing?.shortDescription ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _area = TextEditingController(text: widget.existing?.area ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  late final _instagram = TextEditingController(text: widget.existing?.instagramHandle ?? '');
  late final _capacity = TextEditingController(text: widget.existing?.capacity?.toString() ?? '');
  late final _priceFrom = TextEditingController(text: _num(widget.existing?.priceFrom));
  late final _priceTo = TextEditingController(text: _num(widget.existing?.priceTo));
  late final _priceNote = TextEditingController(text: widget.existing?.priceNote ?? '');
  late final _phone = TextEditingController(text: widget.private?.phone ?? '');
  late final _whatsapp = TextEditingController(text: widget.private?.whatsapp ?? '');
  bool _busy = false;
  String? _error;

  static String _num(double? v) => v == null ? '' : v.round().toString();

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _short,
      _desc,
      _area,
      _address,
      _instagram,
      _capacity,
      _priceFrom,
      _priceTo,
      _priceNote,
      _phone,
      _whatsapp
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  double? _d(TextEditingController c) => double.tryParse(normalizePhone(c.text).replaceAll(',', ''));

  Future<void> _save() async {
    if (_category == null) {
      setState(() => _error = 'اختر فئة الخدمة');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final handle =
        _t(_instagram)?.replaceAll('@', '').replaceAll(RegExp(r'^.*instagram\.com/'), '').replaceAll('/', '');
    final fields = <String, dynamic>{
      'category_id': _category,
      'business_name': _name.text.trim(),
      'short_description': _t(_short),
      'description': _t(_desc),
      'area': _t(_area),
      'address': _t(_address),
      'instagram_url': handle == null ? null : 'https://www.instagram.com/$handle',
      'capacity': _category == 'halls' ? int.tryParse(normalizePhone(_capacity.text)) : null,
      'price_from': _d(_priceFrom),
      'price_to': _d(_priceTo),
      'price_note': _t(_priceNote),
    };
    final repo = ref.read(providerPortalRepositoryProvider);
    try {
      final String id;
      if (_isEdit) {
        id = widget.existing!.id;
        await repo.updateProvider(id, fields);
      } else {
        id = await repo.createProvider(ref.read(authNotifierProvider).user!.id, fields);
      }
      await repo.savePrivate(
        id,
        ProviderPrivate(
          phone: _t(_phone) == null ? null : normalizePhone(_phone.text),
          whatsapp: _t(_whatsapp) == null ? null : normalizePhone(_whatsapp.text),
          email: widget.private?.email,
        ),
      );
      ref.invalidate(myBusinessProvider);
      ref.invalidate(myBusinessPrivateProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_isEdit ? 'تم حفظ التعديلات' : 'تم إنشاء ملفك كمسودة')));
      context.canPop() ? context.pop() : context.go('/p/dashboard');
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hall = _category == 'halls';
    Widget gap() => const SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الملف التجاري' : 'إنشاء الملف التجاري')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            ContentFrame(
              maxWidth: 720,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!_isEdit)
                  const InfoBanner(
                    message: 'يُحفظ ملفك كمسودة ولا يظهر للعملاء حتى ترسله للمراجعة ويوافق عليه فريق SAWA.',
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  InfoBanner(message: _error!, color: AppColors.error, icon: Icons.error_outline),
                ],
                const SizedBox(height: 20),
                Text('فئة الخدمة', style: AppTextStyles.h3),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in widget.categories)
                    ChoiceChip(
                      avatar: Icon(categoryIcon(c.id),
                          size: 18, color: _category == c.id ? Colors.white : AppColors.primary),
                      label: Text(c.nameAr),
                      selected: _category == c.id,
                      selectedColor: AppColors.primary,
                      showCheckmark: false,
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: _category == c.id ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _category = c.id),
                    ),
                ]),
                const SizedBox(height: 24),
                _Group(title: 'معلومات النشاط', children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'اسم النشاط التجاري *'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'الاسم مطلوب';
                      if (t.length > 150) return 'الاسم طويل جداً';
                      return null;
                    },
                  ),
                  gap(),
                  TextFormField(
                    controller: _short,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'وصف مختصر (يظهر على البطاقة)'),
                  ),
                  TextFormField(
                    controller: _desc,
                    maxLength: 3000,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'الوصف الكامل', alignLabelWithHint: true),
                  ),
                ]),
                _Group(title: 'الموقع', children: [
                  TextFormField(
                    controller: _area,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'المنطقة في بغداد', hintText: 'مثلاً: المنصور'),
                  ),
                  TextFormField(
                    controller: _address,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'العنوان التفصيلي'),
                  ),
                ]),
                _Group(title: 'الأسعار والسعة', children: [
                  if (hall) ...[
                    TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'السعة (عدد الضيوف)'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(normalizePhone(v));
                        return (n == null || n < 1 || n > 100000) ? 'رقم غير صحيح' : null;
                      },
                    ),
                    gap(),
                  ],
                  Row(children: [
                    Expanded(child: _moneyField(_priceFrom, 'السعر يبدأ من (د.ع)')),
                    const SizedBox(width: 12),
                    Expanded(child: _moneyField(_priceTo, 'إلى (اختياري)')),
                  ]),
                  gap(),
                  TextFormField(
                    controller: _priceNote,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة السعر',
                      hintText: 'مثلاً: السعر يختلف حسب اليوم',
                    ),
                  ),
                  Text('العروض المؤقتة أضفها كـ«عرض» في الباقات، وليس كسعر أساسي.', style: AppTextStyles.caption),
                ]),
                _Group(title: 'التواصل', children: [
                  TextFormField(
                    controller: _instagram,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'حساب إنستغرام (عام)', prefixText: '@'),
                    validator: (v) {
                      final t = v?.trim().replaceAll('@', '') ?? '';
                      if (t.isEmpty) return null;
                      final h = t.replaceAll(RegExp(r'^.*instagram\.com/'), '').replaceAll('/', '');
                      return RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(h) ? null : 'اسم حساب غير صحيح';
                    },
                  ),
                  gap(),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'هاتف النشاط (خاص)', hintText: '07XXXXXXXXX'),
                    validator: (v) => (v == null || v.trim().isEmpty || isValidPhone(v)) ? null : 'رقم غير صحيح',
                  ),
                  gap(),
                  TextFormField(
                    controller: _whatsapp,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'واتساب (خاص)'),
                    validator: (v) => (v == null || v.trim().isEmpty || isValidPhone(v)) ? null : 'رقم غير صحيح',
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('أرقامك لا تظهر للعملاء — يستخدمها فريق SAWA فقط لتحويل الطلبات إليك.',
                          style: AppTextStyles.caption),
                    ),
                  ]),
                ]),
                const SizedBox(height: 8),
                AppPrimaryButton(label: _isEdit ? 'حفظ التعديلات' : 'إنشاء الملف', isLoading: _busy, onPressed: _save),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _moneyField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final d = _d(c);
          if (d == null || d < 0) return 'رقم غير صحيح';
          if (c == _priceTo && _d(_priceFrom) != null && d < _d(_priceFrom)!) return 'أقل من سعر البداية';
          return null;
        },
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: AppTextStyles.h3),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}
