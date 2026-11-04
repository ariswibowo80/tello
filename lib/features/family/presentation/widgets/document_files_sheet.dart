import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_launcher.dart';
import '../../domain/entities/family_document.dart';
import 'document_image_viewer.dart';

/// Opens a sheet showing a thumbnail grid of every file in a multi-file
/// [FamilyDocument] (e.g. KTP front + back), so the person can see at a
/// glance which page is which before opening one. Tapping an image opens
/// it in the swipeable gallery viewer, starting at its position among
/// the document's other images; tapping a PDF opens it externally.
void showDocumentFilesSheet(BuildContext context, FamilyDocument document) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      final images = document.files.where((f) => f.kind == DocumentFileKind.image).toList();

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(document.title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${document.files.length} file', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: document.files.length,
                itemBuilder: (context, i) {
                  final file = document.files[i];
                  return _FileThumbnail(
                    file: file,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (file.kind == DocumentFileKind.pdf) {
                        openExternalLink(file.url);
                      } else {
                        showDocumentImageViewer(context, images: images, initialIndex: images.indexOf(file));
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({required this.file, required this.onTap});

  final DocumentFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: AppColors.primaryLight,
        child: InkWell(
          onTap: onTap,
          child: file.kind == DocumentFileKind.pdf
              ? const Center(
                  child: Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 32),
                )
              : CachedNetworkImage(imageUrl: file.url, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
