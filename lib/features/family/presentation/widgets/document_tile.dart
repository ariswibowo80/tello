import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_launcher.dart';
import '../../domain/entities/family_document.dart';
import 'document_files_sheet.dart';
import 'document_image_viewer.dart';
import 'document_type_style.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.document, this.onDelete});

  final FamilyDocument document;
  final VoidCallback? onDelete;

  void _open(BuildContext context) {
    if (document.files.isEmpty) return;
    if (document.files.length > 1) {
      showDocumentFilesSheet(context, document);
      return;
    }
    final file = document.files.first;
    if (file.kind == DocumentFileKind.pdf) {
      openExternalLink(file.url);
    } else {
      showDocumentImageViewer(context, images: [file], initialIndex: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = DocumentTypeStyle.forType(document.docType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeAvatar(style: style, fileCount: document.files.length),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        document.docType,
                        if (document.files.length > 1) '${document.files.length} file',
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    _ExpiryBadge(document: document),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.style, required this.fileCount});

  final DocumentTypeStyle style;
  final int fileCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: style.backgroundColor,
            foregroundColor: style.color,
            child: Icon(style.icon, size: 22),
          ),
          if (fileCount > 1)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$fileCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small status pill: red "Kedaluwarsa" once past the expiry date,
/// amber "Kedaluwarsa dalam N hari" inside the 30-day warning window,
/// or a neutral "Berlaku sampai ..." otherwise. Nothing is shown for a
/// document with no expiry date at all.
class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.document});

  final FamilyDocument document;

  @override
  Widget build(BuildContext context) {
    final expiry = document.expiryDate;
    if (expiry == null) return const SizedBox.shrink();

    final String label;
    final Color color;
    if (document.isExpired) {
      label = 'Kedaluwarsa';
      color = AppColors.error;
    } else if (document.isExpiringWithin(30)) {
      final daysLeft = expiry.difference(DateTime.now()).inDays + 1;
      label = 'Kedaluwarsa dalam $daysLeft hari';
      color = AppColors.warning;
    } else {
      label = 'Berlaku sampai ${DateFormat('d MMM yyyy').format(expiry)}';
      color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
