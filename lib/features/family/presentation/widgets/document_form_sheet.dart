import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/repositories/family_document_repository.dart';
import '../providers/family_document_providers.dart';

/// Opens the "Add document" sheet for a family member or asset. Returns
/// once the document has been uploaded and saved, or null if dismissed.
Future<void> showDocumentFormSheet(
  BuildContext context, {
  required DocumentParentType parentType,
  required String parentId,
  required String folderPath,
  required List<String> docTypePresets,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => _DocumentFormSheet(
      parentType: parentType,
      parentId: parentId,
      folderPath: folderPath,
      docTypePresets: docTypePresets,
    ),
  );
}

class _DocumentFormSheet extends ConsumerStatefulWidget {
  const _DocumentFormSheet({
    required this.parentType,
    required this.parentId,
    required this.folderPath,
    required this.docTypePresets,
  });

  final DocumentParentType parentType;
  final String parentId;
  final String folderPath;
  final List<String> docTypePresets;

  @override
  ConsumerState<_DocumentFormSheet> createState() => _DocumentFormSheetState();
}

class _DocumentFormSheetState extends ConsumerState<_DocumentFormSheet> {
  final _titleController = TextEditingController();
  final _customTypeController = TextEditingController();
  String? _docType;
  DateTime? _expiryDate;

  File? _pickedFile;
  bool _pickedIsPdf = false;
  double? _uploadProgress;
  String? _uploadError;
  DocumentUploadResult? _uploadedResult;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  bool get _isUploading => _pickedFile != null && _uploadedResult == null && _uploadError == null;

  static const String _otherPreset = 'Lainnya';

  /// The docType actually saved — the custom text typed under "Lainnya"
  /// when there is one, otherwise whichever chip is selected.
  String? get _resolvedDocType {
    if (_docType == _otherPreset) {
      final custom = _customTypeController.text.trim();
      return custom.isEmpty ? _otherPreset : custom;
    }
    return _docType;
  }

  Future<void> _pickFromCamera() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (xfile != null) _startUpload(File(xfile.path), isPdf: false);
  }

  Future<void> _pickFromGallery() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile != null) _startUpload(File(xfile.path), isPdf: false);
  }

  Future<void> _pickPdf() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = file?.path;
    if (path != null) _startUpload(File(path), isPdf: true);
  }

  /// Uploading begins the instant a file is picked — not deferred to the
  /// Simpan tap — since Simpan is disabled while [_isUploading] is true.
  /// Deferring the actual upload call to `_save()` would deadlock: the
  /// button would stay disabled forever because nothing had kicked off
  /// the work that clears that state.
  void _startUpload(File file, {required bool isPdf}) {
    setState(() {
      _pickedFile = file;
      _pickedIsPdf = isPdf;
      _uploadProgress = 0;
      _uploadError = null;
      _uploadedResult = null;
    });

    final storage = ref.read(storageServiceProvider);
    final task = storage.uploadDocument(file: file, folderPath: widget.folderPath, isPdf: isPdf);

    task.progress.listen((p) {
      if (mounted) setState(() => _uploadProgress = p);
    });

    task.result.then((result) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = 1;
        _uploadedResult = result;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => _uploadError = e is AppException ? e.message : 'Upload gagal. Silakan coba lagi.');
    });
  }

  void _removePickedFile() {
    // Best-effort cleanup if the upload already finished — nothing else
    // references this file since it was never attached to a saved
    // FamilyDocument.
    final uploaded = _uploadedResult;
    if (uploaded != null) {
      ref.read(storageServiceProvider).deleteMedia(uploaded.storagePath);
    }
    setState(() {
      _pickedFile = null;
      _uploadProgress = null;
      _uploadError = null;
      _uploadedResult = null;
    });
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    final uploaded = _uploadedResult;
    final docType = _resolvedDocType;
    if (uploaded == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih foto atau file PDF dulu.')));
      return;
    }
    if (docType == null || docType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih jenis dokumen.')));
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final docRepo = ref.read(familyDocumentRepositoryProvider);
      final title = _titleController.text.trim().isEmpty ? docType : _titleController.text.trim();
      final document = FamilyDocument(
        id: docRepo.newDocumentId(widget.parentType, widget.parentId),
        title: title,
        docType: docType,
        fileUrl: uploaded.url,
        storagePath: uploaded.storagePath,
        fileKind: uploaded.isPdf ? DocumentFileKind.pdf : DocumentFileKind.image,
        expiryDate: _expiryDate,
        createdAt: DateTime.now(),
      );
      await docRepo.createDocument(widget.parentType, widget.parentId, document);

      if (_expiryDate != null) {
        await NotificationService.instance.scheduleDocumentExpiryReminders(
          documentId: document.id,
          documentTitle: document.title,
          expiryDate: _expiryDate!,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Keyboard inset plus the system nav bar / gesture inset — without
        // the latter, the Simpan button sits under a 3-button nav bar.
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tambah Dokumen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_pickedFile == null)
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      onPressed: _pickFromCamera,
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SourceButton(
                      onPressed: _pickFromGallery,
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SourceButton(
                      onPressed: _pickPdf,
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                    ),
                  ),
                ],
              )
            else
              Card(
                color: AppColors.primaryLight,
                child: ListTile(
                  leading: Icon(_pickedIsPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: AppColors.primary),
                  title: Text(_pickedFile!.path.split('/').last, overflow: TextOverflow.ellipsis),
                  subtitle: _isUploading
                      ? LinearProgressIndicator(value: _uploadProgress)
                      : _uploadError != null
                          ? Text(_uploadError!, style: const TextStyle(color: AppColors.error))
                          : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving ? null : _removePickedFile,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Judul (opsional)', hintText: 'misal: KTP Ayah'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in widget.docTypePresets)
                  ChoiceChip(
                    label: Text(type),
                    selected: _docType == type,
                    onSelected: (_) => setState(() => _docType = type),
                  ),
              ],
            ),
            if (_docType == _otherPreset) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customTypeController,
                decoration: const InputDecoration(
                  labelText: 'Jenis dokumen',
                  hintText: 'misal: Surat Nikah, NPWP',
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickExpiryDate,
              icon: const Icon(Icons.event_busy_rounded, size: 16),
              label: Text(
                _expiryDate == null
                    ? 'Tanggal kedaluwarsa (opsional)'
                    : 'Berlaku sampai ${DateFormat('d MMMM yyyy').format(_expiryDate!)}',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_isSaving || _isUploading) ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact source-picker button (Kamera/Galeri/PDF). Three of these sit
/// in one row with limited width, so the label is wrapped in a
/// [FittedBox] to shrink rather than wrap to a second line on narrower
/// screens or larger system font scales.
class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.onPressed, required this.icon, required this.label});

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }
}
