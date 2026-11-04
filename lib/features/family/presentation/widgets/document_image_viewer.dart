import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/family_document.dart';

/// Full-screen, swipeable viewer for a document's image files, starting
/// at [initialIndex] within [images]. [images] should already be filtered
/// to image-kind files — PDFs open externally instead (see
/// `document_tile.dart`).
void showDocumentImageViewer(BuildContext context, {required List<DocumentFile> images, required int initialIndex}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) => _DocumentImageViewer(
        images: images,
        initialIndex: initialIndex,
      ),
    ),
  );
}

class _DocumentImageViewer extends StatefulWidget {
  const _DocumentImageViewer({required this.images, required this.initialIndex});

  final List<DocumentFile> images;
  final int initialIndex;

  @override
  State<_DocumentImageViewer> createState() => _DocumentImageViewerState();
}

class _DocumentImageViewerState extends State<_DocumentImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              final file = widget.images[i];
              return Center(
                child: Hero(
                  tag: file.storagePath,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: CachedNetworkImage(imageUrl: file.url, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
