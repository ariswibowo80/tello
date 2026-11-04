import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_launcher.dart';
import '../../domain/entities/family_document.dart';
import 'document_image_viewer.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.document, this.onDelete});

  final FamilyDocument document;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final expiry = document.expiryDate;
    final Color? expiryColor = expiry == null
        ? null
        : document.isExpired
            ? AppColors.error
            : document.isExpiringWithin(30)
                ? AppColors.warning
                : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.primary,
        child: Icon(document.fileKind == DocumentFileKind.pdf
            ? Icons.picture_as_pdf_rounded
            : Icons.image_rounded),
      ),
      title: Text(document.title),
      subtitle: Text(
        [
          document.docType,
          if (expiry != null)
            '${document.isExpired ? 'Kedaluwarsa' : 'Berlaku sampai'} ${DateFormat('d MMM yyyy').format(expiry)}',
        ].join(' · '),
        style: expiryColor != null ? TextStyle(color: expiryColor, fontWeight: FontWeight.w600) : null,
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: onDelete,
            )
          : null,
      onTap: () {
        if (document.fileKind == DocumentFileKind.pdf) {
          openExternalLink(document.fileUrl);
        } else {
          showDocumentImageViewer(context, url: document.fileUrl, heroTag: document.storagePath);
        }
      },
    );
  }
}
