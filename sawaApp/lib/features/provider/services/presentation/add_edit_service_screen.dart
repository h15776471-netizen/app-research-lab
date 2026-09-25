import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/errors.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../state/portal_providers.dart';
import 'editor_scaffold.dart';

class AddEditServiceScreen extends StatelessWidget {
  const AddEditServiceScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  Widget build(BuildContext context) {
    return BusinessEditorGate(
      title: serviceId == null ? 'خدمة جديدة' : 'تعديل الخدمة',
      builder: (b) => _ServiceForm(
        business: b,
        existing: b.services.where((s) => s.id == serviceId).firstOrNull,
      ),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({required this.business, this.existing});

  final SawaProvider business;
  final ProviderService? existing;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _from = TextEditingController(text: moneyText(widget.existing?.priceFrom));
  late final _to = TextEditingController(text: moneyText(widget.existing?.priceTo));
  late String? _unit = widget.existing?.unit;
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _desc, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final from = parseMoney(_from.text);
    final to = parseMoney(_to.text);
    try {
      await ref.read(providerPortalRepositoryProvider).saveService(
            widget.business.id,
            {
              'name': _name.text.trim(),
              'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
              'price_from': from,
              'price_to': to,
              'unit': from == null ? null : _unit,
              'is_active': _active,
              if (widget.existing == null) 'sort_order': widget.business.services.length,
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

  @override
  Widget build(BuildContext context) {
    return EditorBody(
      formKey: _form,
      busy: _busy,
      error: _error,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'اسم الخدمة *'),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'الاسم مطلوب';
            return t.length > 150 ? 'الاسم طويل جداً' : null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _desc,
          maxLength: 2000,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'الوصف', alignLabelWithHint: true),
        ),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _from,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'السعر من (د.ع)'),
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
                return (to != null && from != null && to < from) ? 'أقل من سعر البداية' : null;
              },
            ),
          ),
        ]),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: _unit,
          decoration: const InputDecoration(labelText: 'وحدة السعر'),
          items: [
            const DropdownMenuItem(value: null, child: Text('بدون')),
            for (final e in serviceUnits.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _unit = v),
        ),
        const SizedBox(height: 8),
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
