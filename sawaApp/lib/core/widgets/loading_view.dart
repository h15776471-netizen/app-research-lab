import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard Flutter spinner, Primary-colored — no custom loading design
/// (Design Handoff §21: "لا تصميم مخصص").
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
