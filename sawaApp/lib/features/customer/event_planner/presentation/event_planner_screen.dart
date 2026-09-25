import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/sawa_image.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/account_models.dart';
import '../../../../data/models/catalog_models.dart';
import '../../../../data/repositories/requests_repository.dart';
import '../domain/planner_engine.dart';

class EventPlannerScreen extends ConsumerStatefulWidget {
  const EventPlannerScreen({super.key});

  @override
  ConsumerState<EventPlannerScreen> createState() => _EventPlannerScreenState();
}

class _EventPlannerScreenState extends ConsumerState<EventPlannerScreen> {
  static const _titles = ['نوع المناسبة', 'الخدمات المطلوبة', 'التفاصيل', 'الخيارات المناسبة'];

  int _step = 0;
  EventType? _type;
  final Set<String> _services = {};
  int? _guests;
  String? _area;
  DateTime? _date;
  double? _budget;
  final _style = TextEditingController();
  final _guestsCtrl = TextEditingController();

  @override
  void dispose() {
    _style.dispose();
    _guestsCtrl.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
        0 => _type != null,
        1 => _services.isNotEmpty,
        _ => true,
      };

  PlannerCriteria get _criteria => PlannerCriteria(
        eventType: _type ?? EventType.other,
        categoryIds: _services.toList(),
        guestCount: _guests,
        area: _area,
        eventDate: _date,
        budgetMax: _budget,
        style: _style.text.trim().isEmpty ? null : _style.text.trim(),
      );

  void _back() {
    if (_step == 0) {
      context.canPop() ? context.pop() : context.go('/c/home');
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خطّط مناسبتك'),
        leading: IconButton(icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'رجوع', onPressed: _back),
      ),
      body: Column(children: [
        ContentFrame(
          maxWidth: 820,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (var i = 0; i < _titles.length; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Text('الخطوة ${_step + 1} من ${_titles.length} · ${_titles[_step]}', style: AppTextStyles.caption),
            ]),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_step), child: _body()),
          ),
        ),
        if (_step < 3)
          SafeArea(
            top: false,
            child: ContentFrame(
              maxWidth: 820,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(52)),
                  onPressed: _canNext ? () => setState(() => _step++) : null,
                  child: Text(_step == 2 ? 'اعرض الخيارات' : 'التالي'),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _body() => switch (_step) {
        0 => _stepType(),
        1 => _stepServices(),
        2 => _stepDetails(),
        _ => _Results(criteria: _criteria),
      };

  Widget _page(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ContentFrame(maxWidth: 820, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))
        ],
      );

  Widget _stepType() {
    const icons = {
      EventType.wedding: Icons.favorite_outline,
      EventType.engagement: Icons.diamond_outlined,
      EventType.birthday: Icons.cake_outlined,
      EventType.graduation: Icons.school_outlined,
      EventType.corporate: Icons.business_center_outlined,
      EventType.other: Icons.celebration_outlined,
    };
    return _page([
      Text('شنو نوع مناسبتك؟', style: AppTextStyles.h2),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 560 ? 3 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            for (final t in EventType.values)
              _ChoiceTile(
                icon: icons[t]!,
                label: t.labelAr,
                selected: _type == t,
                onTap: () => setState(() {
                  _type = t;
                  _step = 1;
                }),
              ),
          ],
        );
      }),
    ]);
  }

  Widget _stepServices() {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <SawaCategory>[];
    final counts = ref.watch(categoryCountsProvider);
    return _page([
      Text('شنو الخدمات اللي تحتاجها؟', style: AppTextStyles.h2),
      Text('اختر أكثر من خدمة إذا تحب.', style: AppTextStyles.bodySmall),
      const SizedBox(height: 16),
      for (final c in categories)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SelectRow(
            icon: categoryIcon(c.id),
            label: c.nameAr,
            subtitle: (counts[c.id] ?? 0) > 0
                ? '${counts[c.id]} مزود متاح'
                : 'لا مزودين منشورين بعد — نبلغ فريق SAWA باحتياجك',
            selected: _services.contains(c.id),
            onTap: () => setState(() => _services.contains(c.id) ? _services.remove(c.id) : _services.add(c.id)),
          ),
        ),
    ]);
  }

  Widget _stepDetails() {
    final providers = ref.watch(providersProvider).valueOrNull ?? const <SawaProvider>[];
    final areas = knownAreas(providers.where((p) => _services.contains(p.categoryId)).toList());
    return _page([
      Text('التفاصيل (كلها اختيارية)', style: AppTextStyles.h2),
      const SizedBox(height: 18),
      Text('عدد الضيوف', style: AppTextStyles.h3),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final n in const [50, 100, 200, 300, 500])
          ChoiceChip(
            label: Text('$n'),
            selected: _guests == n,
            onSelected: (s) => setState(() {
              _guests = s ? n : null;
              _guestsCtrl.text = s ? '$n' : '';
            }),
          ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _guestsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'عدد آخر', isDense: true),
            onChanged: (v) => setState(() => _guests = int.tryParse(normalizePhone(v))),
          ),
        ),
      ]),
      const SizedBox(height: 20),
      Text('المنطقة في بغداد', style: AppTextStyles.h3),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(
            label: const Text('أي منطقة'), selected: _area == null, onSelected: (_) => setState(() => _area = null)),
        for (final a in areas)
          ChoiceChip(label: Text(a), selected: _area == a, onSelected: (s) => setState(() => _area = s ? a : null)),
      ]),
      if (areas.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('لا توجد مناطق محددة في بيانات الخدمات المختارة.', style: AppTextStyles.caption),
        ),
      const SizedBox(height: 20),
      Text('تاريخ المناسبة', style: AppTextStyles.h3),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: _date ?? now.add(const Duration(days: 30)),
            firstDate: DateTime(now.year, now.month, now.day),
            lastDate: now.add(const Duration(days: 730)),
          );
          if (d != null) setState(() => _date = d);
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(_date == null ? 'اختر التاريخ' : formatDate(_date!)),
      ),
      const SizedBox(height: 20),
      Text('الميزانية التقريبية لكل خدمة', style: AppTextStyles.h3),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(
            label: const Text('غير محددة'),
            selected: _budget == null,
            onSelected: (_) => setState(() => _budget = null)),
        for (final b in const [100000.0, 500000.0, 1000000.0, 1500000.0, 3000000.0])
          ChoiceChip(
            label: Text('حتى ${formatIqd(b)}'),
            selected: _budget == b,
            onSelected: (s) => setState(() => _budget = s ? b : null),
          ),
      ]),
      const SizedBox(height: 20),
      Text('الستايل أو ملاحظات', style: AppTextStyles.h3),
      const SizedBox(height: 8),
      TextField(
        controller: _style,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'مثلاً: ألوان هادئة، كوشة كلاسيكية، تصوير نسائي…'),
      ),
    ]);
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.criteria});

  final PlannerCriteria criteria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(providersProvider).valueOrNull ?? const <SawaProvider>[];
    final categories = {for (final c in ref.watch(categoriesProvider).valueOrNull ?? const <SawaCategory>[]) c.id: c};
    final result = matchProviders(providers, criteria);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      ContentFrame(
        maxWidth: 820,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const InfoBanner(
            icon: Icons.rule_rounded,
            message: 'الترتيب مبني على قواعد واضحة (الفئة، السعة، المنطقة، الميزانية، اكتمال البيانات) — '
                'وليس ذكاءً اصطناعياً. البيانات غير المتوفرة لا تُحتسب ولا تستبعد أحداً.',
          ),
          const SizedBox(height: 16),
          for (final id in criteria.categoryIds) ...[
            SectionHeader(title: categories[id]?.nameAr ?? id),
            const SizedBox(height: 10),
            if (result.byCategory[id]!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'لا يوجد مزود منشور يطابق هذا الطلب حالياً. أرسل احتياجك لفريق SAWA وسنبحث لك.',
                  style: AppTextStyles.bodySmall,
                ),
              )
            else
              for (final m in result.byCategory[id]!.take(5)) _MatchCard(match: m),
            const SizedBox(height: 12),
          ],
          if (result.excluded.isNotEmpty) ...[
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('مستبعد بسبب السعة (${result.excluded.length})', style: AppTextStyles.bodySmall),
              children: [for (final m in result.excluded) _MatchCard(match: m)],
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            color: AppColors.surfaceWarm,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('تحب فريق SAWA يساعدك؟', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text('أرسل احتياجاتك كما اخترتها، ونتواصل معك بخيارات مناسبة.', style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(50)),
                onPressed: () => _sendInquiry(context, ref),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('أرسل طلب التخطيط'),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _sendInquiry(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(requestsRepositoryProvider);
    if (!repo.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(offlineMessage)));
      return;
    }
    final user = ref.read(authNotifierProvider).user;
    final ref0 = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InquirySheet(
          criteria: criteria, guest: user == null, defaultName: user?.fullName, defaultPhone: user?.phone),
    );
    if (ref0 != null && context.mounted) {
      context.pushReplacementNamed(AppRoute.contactSuccess, queryParameters: {'ref': ref0, 'kind': 'inquiry'});
    }
  }
}

class _InquirySheet extends ConsumerStatefulWidget {
  const _InquirySheet({required this.criteria, required this.guest, this.defaultName, this.defaultPhone});

  final PlannerCriteria criteria;
  final bool guest;
  final String? defaultName;
  final String? defaultPhone;

  @override
  ConsumerState<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends ConsumerState<_InquirySheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.defaultName ?? '');
  late final _phone = TextEditingController(text: widget.defaultPhone ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final c = widget.criteria;
    try {
      final r = await ref.read(requestsRepositoryProvider).createInquiry(InquiryInput(
            eventType: c.eventType,
            guestCount: c.guestCount,
            area: c.area,
            eventDate: c.eventDate,
            budgetMax: c.budgetMax,
            services: c.categoryIds,
            style: c.style,
            guestName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            guestContact: _phone.text.trim().isEmpty ? null : normalizePhone(_phone.text),
          ));
      if (mounted) Navigator.pop(context, r.referenceCode);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('إرسال طلب التخطيط', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text('يصل إلى فريق SAWA فقط.', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            const SizedBox(height: 10),
          ],
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم'),
            validator: (v) => widget.guest && (v == null || v.trim().isEmpty) ? 'يرجى كتابة الاسم' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
                labelText: widget.guest ? 'رقم الهاتف' : 'رقم الهاتف (اختياري)', hintText: '07XXXXXXXXX'),
            validator: (v) {
              final empty = v == null || v.trim().isEmpty;
              if (widget.guest && empty) return 'يرجى إدخال رقم للتواصل';
              if (!empty && !isValidPhone(v)) return 'رقم الهاتف غير صحيح';
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('إرسال'),
          ),
        ]),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final PlannerMatch match;

  @override
  Widget build(BuildContext context) {
    final p = match.provider;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => context.pushNamed(AppRoute.providerDetails, pathParameters: {'providerId': p.id}),
        semanticLabel: p.businessName,
        child: SurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 76, height: 76, child: SawaImage(url: p.cardImageUrl, categoryId: p.categoryId)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.businessName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                for (final r in match.reasons.take(4))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(
                        switch (r.kind) {
                          ReasonKind.match => Icons.check_circle_outline,
                          ReasonKind.warning => Icons.error_outline,
                          ReasonKind.info => Icons.info_outline,
                        },
                        size: 14,
                        color: switch (r.kind) {
                          ReasonKind.match => AppColors.success,
                          ReasonKind.warning => AppColors.warning,
                          ReasonKind.info => AppColors.textHint,
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(r.text, style: AppTextStyles.caption)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          boxShadow: selected ? AppColors.liftShadow : AppColors.softShadow,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 30, color: selected ? Colors.white : AppColors.primary),
          const SizedBox(height: 8),
          Text(label,
              style: AppTextStyles.body.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow(
      {required this.icon, required this.label, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle, style: AppTextStyles.caption),
            ]),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              key: ValueKey(selected),
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
        ]),
      ),
    );
  }
}
