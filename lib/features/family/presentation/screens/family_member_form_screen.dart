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
import '../../domain/entities/family_member.dart';
import '../providers/family_member_providers.dart';

class FamilyMemberFormScreen extends ConsumerStatefulWidget {
  const FamilyMemberFormScreen({super.key, this.existingMember});

  final FamilyMember? existingMember;

  @override
  ConsumerState<FamilyMemberFormScreen> createState() => _FamilyMemberFormScreenState();
}

class _FamilyMemberFormScreenState extends ConsumerState<FamilyMemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  FamilyRelationship _relationship = FamilyRelationship.other;
  DateTime? _birthDate;
  String? _photoUrl;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existingMember != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMember;
    if (existing != null) {
      _nameController.text = existing.name;
      _notesController.text = existing.notes ?? '';
      _relationship = existing.relationship;
      _birthDate = existing.birthDate;
      _photoUrl = existing.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      final memberId = widget.existingMember?.id ?? ref.read(familyMemberRepositoryProvider).newMemberId();
      final storage = ref.read(storageServiceProvider);
      final task = storage.uploadImage(
        file: File(xfile.path),
        folderPath: StoragePaths.familyMemberFiles(householdId, memberId),
      );
      final item = await task.result;
      if (mounted) setState(() => _photoUrl = item.url);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(DateTime.now().year - 20),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final existing = widget.existingMember;
    final notes = _notesController.text.trim();
    final repo = ref.read(familyMemberRepositoryProvider);
    final member = FamilyMember(
      id: existing?.id ?? repo.newMemberId(),
      name: _nameController.text.trim(),
      relationship: _relationship,
      birthDate: _birthDate,
      photoUrl: _photoUrl,
      notes: notes.isEmpty ? null : notes,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await repo.updateMember(member);
      } else {
        await repo.createMember(member);
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
        title: Text(_isEditing ? 'Edit Anggota Keluarga' : 'Tambah Anggota Keluarga'),
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
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: hasPhoto ? NetworkImage(_photoUrl!) : null,
                        child: !hasPhoto
                            ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28)
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
              const _SectionLabel('Nama'),
              TextFormField(
                controller: _nameController,
                maxLength: AppLimits.maxTitleLength,
                decoration: const InputDecoration(hintText: 'misal: Budi Santoso'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi nama anggota keluarga.' : null,
              ),
              const _SectionLabel('Hubungan'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in FamilyRelationship.values)
                    ChoiceChip(
                      label: Text(r.label),
                      avatar: Icon(r.icon, size: 16),
                      selected: _relationship == r,
                      onSelected: (_) => setState(() => _relationship = r),
                    ),
                ],
              ),
              const _SectionLabel('Tanggal Lahir'),
              OutlinedButton.icon(
                onPressed: _pickBirthDate,
                icon: const Icon(Icons.cake_rounded, size: 16),
                label: Text(_birthDate == null
                    ? 'Pilih tanggal (opsional)'
                    : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
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
