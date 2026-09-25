import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sawa_image.dart';
import '../../../data/models/catalog_models.dart';

/// Full-screen, zoomable photo viewer.
Future<void> openGalleryViewer(BuildContext context, List<ProviderImage> images, int initial, String categoryId) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, __, ___) => _GalleryViewer(images: images, initial: initial, categoryId: categoryId),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({required this.images, required this.initial, required this.categoryId});

  final List<ProviderImage> images;
  final int initial;
  final String categoryId;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}', style: AppTextStyles.body.copyWith(color: Colors.white)),
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _page,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: SawaImage(url: widget.images[i].url, categoryId: widget.categoryId, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        if (img.altText != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(img.altText!,
                  style: AppTextStyles.body.copyWith(color: Colors.white70), textAlign: TextAlign.center),
            ),
          ),
      ]),
    );
  }
}
