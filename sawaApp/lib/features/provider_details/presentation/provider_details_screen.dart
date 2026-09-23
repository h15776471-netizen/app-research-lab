import 'package:flutter/material.dart';

/// PHASE 1 PLACEHOLDER — image gallery, badge, Instagram link, and sticky
/// "طلب تواصل" CTA (Design Handoff §17) land in Phase 3.
class ProviderDetailsScreen extends StatelessWidget {
  const ProviderDetailsScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المزوّد')),
      body: Center(
        child: Text('Provider #$providerId — قيد الإنشاء (Phase 3)'),
      ),
    );
  }
}
