import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../state/services_notifier.dart';

class AddEditServiceScreen extends ConsumerStatefulWidget {
  const AddEditServiceScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  ConsumerState<AddEditServiceScreen> createState() =>
      _AddEditServiceScreenState();
}

class _AddEditServiceScreenState
    extends ConsumerState<AddEditServiceScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool get _isEdit => widget.serviceId != null;

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_rebuild);
    _descCtrl.addListener(_rebuild);
    if (_isEdit) _loadExisting();
  }

  void _rebuild() => setState(() {});

  void _loadExisting() {
    final services = ref.read(servicesNotifierProvider).services;
    final service =
        services.where((s) => s.id == widget.serviceId).firstOrNull;
    if (service != null) {
      _titleCtrl.text = service.title;
      _descCtrl.text = service.description;
      _priceCtrl.text = service.priceText ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(servicesNotifierProvider.notifier).addService(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          priceText: _priceCtrl.text.trim().isEmpty
              ? null
              : _priceCtrl.text.trim(),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(servicesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل الخدمة' : 'إضافة خدمة'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  _isEdit
                      ? 'عدّل تفاصيل الخدمة'
                      : 'أضف خدمة جديدة لملفك الشخصي',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),

                TextField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخدمة *',
                    prefixIcon: Icon(Icons.design_services_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'وصف الخدمة *',
                    hintText: 'اشرح ما تقدمه من خدمات...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                TextField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نطاق السعر (اختياري)',
                    hintText: 'مثال: ٣٠٠ - ٦٠٠ دولار',
                    prefixIcon: Icon(Icons.attach_money_outlined),
                  ),
                ),

                if (state.hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: AppPrimaryButton(
              label: _isEdit ? 'حفظ التعديلات' : 'إضافة الخدمة',
              isLoading: state.isLoading,
              onPressed: _valid && !state.isLoading ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
