import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../domain/entities/family_asset.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/repositories/family_document_repository.dart';
import '../providers/family_asset_providers.dart';
import '../providers/family_document_providers.dart';
import '../widgets/document_form_sheet.dart';
import '../widgets/document_tile.dart';

class FamilyAssetDetailScreen extends ConsumerWidget {
  const FamilyAssetDetailScreen({super.key, required this.assetId});

  final String assetId;

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
          .deleteDocument(DocumentParentType.familyAsset, assetId, document.id);
      await ref.read(storageServiceProvider).deleteMedia(document.storagePath);
      await NotificationService.instance.cancelDocumentExpiryReminders(document.id);
    } on AppException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteAsset(BuildContext context, WidgetRef ref, FamilyAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus aset ini?'),
        content: Text('"${asset.name}" beserta semua dokumennya akan dihapus permanen.'),
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
      final documents = ref.read(familyDocumentsProvider((DocumentParentType.familyAsset, asset.id))).valueOrNull ??
          const <FamilyDocument>[];
      for (final doc in documents) {
        await ref.read(storageServiceProvider).deleteMedia(doc.storagePath);
        await NotificationService.instance.cancelDocumentExpiryReminders(doc.id);
      }
      await ref.read(familyAssetRepositoryProvider).deleteAsset(asset.id);
      if (context.mounted) context.pop();
    } on AppException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetAsync = ref.watch(familyAssetProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Aset'),
        actions: [
          assetAsync.when(
            data: (asset) => asset == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await context.push<bool>(AppRoutes.familyAssetForm, extra: asset);
                      } else if (value == 'delete') {
                        await _deleteAsset(context, ref, asset);
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
      floatingActionButton: assetAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () {
                final asset = assetAsync.value!;
                final householdId = ref.read(householdIdProvider).valueOrNull;
                if (householdId == null) return;
                showDocumentFormSheet(
                  context,
                  parentType: DocumentParentType.familyAsset,
                  parentId: asset.id,
                  folderPath: StoragePaths.familyAssetFiles(householdId, asset.id),
                  docTypePresets: DocumentTypePresets.asset,
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: assetAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e is AppException ? e.message : 'Terjadi kesalahan. Silakan coba lagi.',
          onRetry: () => ref.invalidate(familyAssetProvider(assetId)),
        ),
        data: (asset) {
          if (asset == null) {
            return const EmptyState(icon: Icons.inventory_2_rounded, title: 'Aset tidak ditemukan');
          }
          final hasPhoto = asset.photoUrl != null && asset.photoUrl!.isNotEmpty;
          final documentsAsync = ref.watch(familyDocumentsProvider((DocumentParentType.familyAsset, asset.id)));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.planAccentLight,
                        borderRadius: BorderRadius.circular(16),
                        image: hasPhoto ? DecorationImage(image: NetworkImage(asset.photoUrl!), fit: BoxFit.cover) : null,
                      ),
                      child: !hasPhoto ? Icon(asset.category.icon, color: AppColors.planAccent, size: 36) : null,
                    ),
                    const SizedBox(height: 12),
                    Text(asset.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      [
                        asset.category.label,
                        if (asset.purchaseDate != null) DateFormat('d MMMM yyyy').format(asset.purchaseDate!),
                        if (asset.estimatedValue != null)
                          'Rp ${NumberFormat.decimalPattern('id').format(asset.estimatedValue)}',
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (asset.notes != null && asset.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(asset.notes!, style: Theme.of(context).textTheme.bodyMedium),
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
