import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/repositories/family_document_repository.dart';
import '../providers/family_document_providers.dart';
import '../providers/family_member_providers.dart';
import '../widgets/document_form_sheet.dart';
import '../widgets/document_tile.dart';

class FamilyMemberDetailScreen extends ConsumerWidget {
  const FamilyMemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  Future<void> _deleteDocument(BuildContext context, WidgetRef ref, FamilyDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus dokumen ini?'),
        content: Text('"${document.title}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(familyDocumentRepositoryProvider)
          .deleteDocument(DocumentParentType.familyMember, memberId, document.id);
      await ref.read(storageServiceProvider).deleteMedia(document.storagePath);
      await NotificationService.instance.cancelDocumentExpiryReminders(document.id);
    } on AppException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteMember(BuildContext context, WidgetRef ref, FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus anggota keluarga ini?'),
        content: Text('"${member.name}" beserta semua dokumennya akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final documents = ref.read(familyDocumentsProvider((DocumentParentType.familyMember, member.id))).valueOrNull ??
          const <FamilyDocument>[];
      for (final doc in documents) {
        await ref.read(storageServiceProvider).deleteMedia(doc.storagePath);
        await NotificationService.instance.cancelDocumentExpiryReminders(doc.id);
      }
      await ref.read(familyMemberRepositoryProvider).deleteMember(member.id);
      if (context.mounted) context.pop();
    } on AppException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(familyMemberProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Anggota'),
        actions: [
          memberAsync.when(
            data: (member) => member == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await context.push<bool>(AppRoutes.familyMemberForm, extra: member);
                      } else if (value == 'delete') {
                        await _deleteMember(context, ref, member);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: memberAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () {
                final member = memberAsync.value!;
                final householdId = ref.read(householdIdProvider).valueOrNull;
                if (householdId == null) return;
                showDocumentFormSheet(
                  context,
                  parentType: DocumentParentType.familyMember,
                  parentId: member.id,
                  folderPath: StoragePaths.familyMemberFiles(householdId, member.id),
                  docTypePresets: DocumentTypePresets.member,
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: memberAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e is AppException ? e.message : 'Terjadi kesalahan. Silakan coba lagi.',
          onRetry: () => ref.invalidate(familyMemberProvider(memberId)),
        ),
        data: (member) {
          if (member == null) {
            return const EmptyState(icon: Icons.person_off_rounded, title: 'Anggota tidak ditemukan');
          }
          final hasPhoto = member.photoUrl != null && member.photoUrl!.isNotEmpty;
          final documentsAsync = ref.watch(familyDocumentsProvider((DocumentParentType.familyMember, member.id)));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: hasPhoto ? CachedNetworkImageProvider(member.photoUrl!) : null,
                      child: !hasPhoto
                          ? Text(member.initials,
                              style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(member.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      [member.relationship.label, if (member.age != null) '${member.age} tahun'].join(' · '),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (member.notes != null && member.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(member.notes!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const Divider(height: 32),
              Text('Dokumen', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              documentsAsync.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: e is AppException ? e.message : 'Gagal memuat dokumen.'),
                data: (documents) {
                  if (documents.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Belum ada dokumen. Ketuk + untuk menambah.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return Column(
                    children: [
                      for (final doc in documents)
                        DocumentTile(document: doc, onDelete: () => _deleteDocument(context, ref, doc)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
