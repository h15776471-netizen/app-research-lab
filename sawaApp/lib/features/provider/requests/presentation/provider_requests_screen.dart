import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';

class ProviderRequestsScreen extends ConsumerWidget {
  const ProviderRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الطلبات'),
        automaticallyImplyLeading: false,
      ),
      body: const EmptyStateView(
        icon: Icons.inbox_outlined,
        title: 'لا توجد طلبات بعد',
        message: 'عندما يتواصل العملاء معك، ستظهر طلباتهم هنا',
      ),
    );
  }
}
