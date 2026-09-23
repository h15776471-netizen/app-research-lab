import 'package:flutter/material.dart';

import '../data/provider_category.dart';

/// PHASE 1 PLACEHOLDER — real ProviderCard list + Empty/Loading states
/// (Skill Module 4/9) land in Phase 3, backed by
/// providersByCategoryProvider (already wired — see
/// providers_list_notifier.dart).
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.category});

  final ProviderCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.labelAr)),
      body: Center(
        child: Text('شاشة ${category.labelAr} — قيد الإنشاء (Phase 3)'),
      ),
    );
  }
}
