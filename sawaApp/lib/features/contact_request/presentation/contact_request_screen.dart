import 'package:flutter/material.dart';

/// PHASE 1 PLACEHOLDER ONLY.
///
/// Deliberately NOT wired to any submission logic yet — no button here
/// navigates to Contact Success. Skill Module 6 explicitly forbids showing
/// the success screen before a real, confirmed Supabase insert; even as
/// placeholder scaffolding, no shortcut that could look like "fake
/// success" is added here. The real form (local widget state + validation)
/// and the submission Notifier (idle/submitting/success/error) are built
/// in Phase 4, after Phase 1.5's Supabase/RLS spike is verified.
class ContactRequestScreen extends StatelessWidget {
  const ContactRequestScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أرسل طلب تواصلك')),
      body: Center(
        child: Text(
          'فورم طلب التواصل لمزوّد #$providerId — قيد الإنشاء (Phase 4)',
        ),
      ),
    );
  }
}
