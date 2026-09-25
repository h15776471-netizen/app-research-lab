import 'package:flutter/material.dart';

import 'provider_browser.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اكتشف المزودين'), automaticallyImplyLeading: false),
      body: ProviderBrowser(initialQuery: initialQuery),
    );
  }
}
