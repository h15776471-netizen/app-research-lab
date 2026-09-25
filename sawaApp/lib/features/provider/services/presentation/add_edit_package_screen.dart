import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../state/portal_providers.dart';
import 'editor_scaffold.dart';

/// A package, or a time-bound offer (`is_offer`). Offers are shown with an
/// «عرض» tag and are never used as the provider's base price.
class AddEditPackageScreen extends StatelessWidget {
  const AddEditPackageScreen({super.key, this.packageId});

  final String? packageId;

  @override
  Widget build(BuildContext context) {
    return BusinessEditorGate(
      title: packageId == null ? 'باقة أو عرض جديد' : 'تعديل الباقة',
      builder: (b) => _PackageForm(business: b, existing: b.packages.where((k) => k.id == packageId).firstOrNull),
    );
  }
}

class _PackageForm extends ConsumerStatefulWidget {
  const _PackageForm({required this.business, this.existing});

  final SawaProvider business;
  final ProviderPackage? existing;

  @override
  ConsumerState<_PackageForm> createState() => _PackageFormState();
}

class _PackageFormState extends ConsumerState<_PackageForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _conditions = TextEditingController(text: widget.existing?.conditions ?? '');
  late final _from = TextEditingController(text: moneyText(widget.existing?.priceFrom));
  late final _to = TextEditingController(text: moneyText(widget.existing?.priceTo));
  late bool _offer = widget.existing?.isOffer ?? false;
  late bool _active = widget.existing?.isActive ?? true;
  late DateTime? _validFrom = widget.existing?.validFrom;
  late DateTime? _validUntil = widget.existing?.validUntil;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _desc, _conditions, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_validFrom != null && _validUntil != null && _validUntil!.isBefore(_validFrom!)) {
      setState(() => _error = 'تاريخ الانتهاء قبل تاريخ البداية');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref.read(providerPortalRepositoryProvider).savePackage(
            widget.business.id,
            {
              'title': _title.text.trim(),
              'description': t(_desc),
              'conditions': t(_conditions),
              'price_from': parseMoney(_from.text),
              'price_to': parseMoney(_to.text),
              'is_offer': _offer,
              'valid_from': _offer ? _date(_validFrom) : null,
              'valid_until': _offer ? _date(_validUntil) : null,
              'is_active': _active,
              if (widget.existing == null) 'sort_order': widget.business.packages.length,
            },
            id: widget.existing?.id,
          );
      ref.invalidate(myBusinessProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _validFrom : _validUntil) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => start ? _validFrom = d : _validUntil = d);
  }

  @override
  Widget build(BuildContext context) {
    return EditorBody(
      formKey: _form,
      busy: _busy,
      error: _error,
      onSave: _save,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('باقة دائمة'), icon: Icon(Icons.inventory_2_outlined)),
            ButtonSegment(value: true, label: Text('عرض مؤقت'), icon: Icon(Icons.local_offer_outlined)),
          ],
          selected: {_offer},
          onSelectionChanged: (s) => setState(() => _offer = s.first),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'العنوان *', hintText: 'مثلاً: الباقة الذهبية'),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'العنوان مطلوب';
            return t.length > 150 ? 'العنوان طويل جداً' : null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _desc,
          maxLength: 2000,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'ماذا تشمل؟', alignLabelWithHint: true),
        ),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _from,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'السعر (د.ع)'),
              validator: validateMoney,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _to,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'إلى (اختياري)'),
              validator: (v) {
                final e = validateMoney(v);
                if (e != null) return e;
                final to = parseMoney(v ?? ''), from = parseMoney(_from.text);
                return (to != null && from != null && to < from) ? 'أقل من السعر الأول' : null;
              },
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _conditions,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'الشروط والملاحظات', hintText: 'مثلاً: أيام الأسبوع فقط'),
        ),
        if (_offer) ...[
          Text('مدة العرض (اختياري)', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pick(true),
                child: Text(_validFrom == null ? 'من تاريخ' : formatDate(_validFrom!)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pick(false),
                child: Text(_validUntil == null ? 'إلى تاريخ' : formatDate(_validUntil!)),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('العرض المنتهي يُخفى تلقائياً عن العملاء.', style: AppTextStyles.caption),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ظاهرة للعملاء'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}
