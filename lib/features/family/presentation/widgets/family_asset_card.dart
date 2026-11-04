import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/family_asset.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/repositories/family_document_repository.dart';
import '../providers/family_document_providers.dart';

class FamilyAssetCard extends ConsumerWidget {
  const FamilyAssetCard({super.key, required this.asset, required this.onTap});

  final FamilyAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents =
        ref.watch(familyDocumentsProvider((DocumentParentType.familyAsset, asset.id))).valueOrNull ??
            const <FamilyDocument>[];
    final expiringCount = documents.where((d) => d.isExpired || d.isExpiringWithin(30)).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.planAccentLight,
          foregroundColor: AppColors.planAccent,
          child: Icon(asset.category.icon),
        ),
        title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${asset.category.label} · ${documents.length} dokumen'),
        trailing: expiringCount > 0
            ? Badge(
                backgroundColor: AppColors.error,
                label: Text('$expiringCount'),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              )
            : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ),
    );
  }
}
