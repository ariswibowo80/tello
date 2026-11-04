import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../domain/entities/family_asset.dart';
import '../providers/family_asset_providers.dart';

class FamilyAssetFormScreen extends ConsumerStatefulWidget {
  const FamilyAssetFormScreen({super.key, this.existingAsset});

  final FamilyAsset? existingAsset;

  @override
  ConsumerState<FamilyAssetFormScreen> createState() => _FamilyAssetFormScreenState();
}

class _FamilyAssetFormScreenState extends ConsumerState<FamilyAssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();

  AssetCategory _category = AssetCategory.other;
  DateTime? _purchaseDate;
  String? _photoUrl;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existingAsset != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAsset;
    if (existing != null) {
      _nameController.text = existing.name;
      _valueController.text = existing.estimatedValue?.toStringAsFixed(0) ?? '';
      _notesController.text = existing.notes ?? '';
      _category = existing.category;
      _purchaseDate = existing.purchaseDate;
      _photoUrl = existing.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    final householdId = ref.read(householdIdProvider).valueOrNull;
    if (householdId == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final assetId = widget.existingAsset?.id ?? ref.read(familyAssetRepositoryProvider).newAssetId();
      final storage = ref.read(storageServiceProvider);
      final task = storage.uploadImage(
        file: File(xfile.path),
        folderPath: StoragePaths.familyAssetFiles(householdId, assetId),
      );
      final item = await task.result;
      if (mounted) setState(() => _photoUrl = item.url);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final existing = widget.existingAsset;
    final notes = _notesController.text.trim();
    final valueText = _valueController.text.trim();
    final repo = ref.read(familyAssetRepositoryProvider);
    final asset = FamilyAsset(
      id: existing?.id ?? repo.newAssetId(),
      name: _nameController.text.trim(),
      category: _category,
      purchaseDate: _purchaseDate,
      estimatedValue: valueText.isEmpty ? null : double.tryParse(valueText),
      photoUrl: _photoUrl,
      notes: notes.isEmpty ? null : notes,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await repo.updateAsset(asset);
      } else {
        await repo.createAsset(asset);
      }
      if (mounted) context.pop(true);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Aset' : 'Tambah Aset'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.planAccentLight,
                          borderRadius: BorderRadius.circular(16),
                          image: hasPhoto ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover) : null,
                        ),
                        child: !hasPhoto
                            ? const Icon(Icons.add_a_photo_rounded, color: AppColors.planAccent, size: 28)
                            : null,
                      ),
                      if (_isUploadingPhoto)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Nama Aset'),
              TextFormField(
                controller: _nameController,
                maxLength: AppLimits.maxTitleLength,
                decoration: const InputDecoration(hintText: 'misal: Rumah Jakarta, Toyota Avanza'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi nama aset.' : null,
              ),
              const _SectionLabel('Kategori'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in AssetCategory.values)
                    ChoiceChip(
                      label: Text(c.label),
                      avatar: Icon(c.icon, size: 16),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const _SectionLabel('Tanggal Perolehan'),
              OutlinedButton.icon(
                onPressed: _pickPurchaseDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_purchaseDate == null
                    ? 'Pilih tanggal (opsional)'
                    : '${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}'),
              ),
              const _SectionLabel('Estimasi Nilai (Rp)'),
              TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'misal: 500000000 (opsional)'),
              ),
              const _SectionLabel('Catatan'),
              TextFormField(
                controller: _notesController,
                maxLength: AppLimits.maxNoteLength,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Catatan tambahan (opsional)'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
