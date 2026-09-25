import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive_shell.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.child});

  final Widget child;

  static const destinations = [
    ShellDestination(path: '/c/home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الرئيسية'),
    ShellDestination(
        path: '/c/explore', icon: Icons.search_rounded, activeIcon: Icons.manage_search_rounded, label: 'اكتشف'),
    ShellDestination(path: '/c/requests', icon: Icons.inbox_outlined, activeIcon: Icons.inbox_rounded, label: 'طلباتي'),
    ShellDestination(path: '/c/profile', icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) => AdaptiveShell(destinations: destinations, child: child);
}
