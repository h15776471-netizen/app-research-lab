import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive_shell.dart';

class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key, required this.child});

  final Widget child;

  static const destinations = [
    ShellDestination(
        path: '/p/dashboard',
        icon: Icons.space_dashboard_outlined,
        activeIcon: Icons.space_dashboard_rounded,
        label: 'لوحة التحكم'),
    ShellDestination(
        path: '/p/services',
        icon: Icons.design_services_outlined,
        activeIcon: Icons.design_services_rounded,
        label: 'الخدمات والباقات'),
    ShellDestination(
        path: '/p/requests', icon: Icons.inbox_outlined, activeIcon: Icons.inbox_rounded, label: 'الطلبات'),
    ShellDestination(
        path: '/p/profile',
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'ملفي التجاري'),
  ];

  @override
  Widget build(BuildContext context) => AdaptiveShell(destinations: destinations, child: child);
}
