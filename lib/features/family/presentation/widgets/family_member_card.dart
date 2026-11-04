import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/repositories/family_document_repository.dart';
import '../providers/family_document_providers.dart';

class FamilyMemberCard extends ConsumerWidget {
  const FamilyMemberCard({super.key, required this.member, required this.onTap});

  final FamilyMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = member.photoUrl != null && member.photoUrl!.isNotEmpty;
    final documents =
        ref.watch(familyDocumentsProvider((DocumentParentType.familyMember, member.id))).valueOrNull ??
            const <FamilyDocument>[];
    final expiringCount = documents.where((d) => d.isExpired || d.isExpiringWithin(30)).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: hasPhoto ? CachedNetworkImageProvider(member.photoUrl!) : null,
          child: !hasPhoto
              ? Text(member.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))
              : null,
        ),
        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            member.relationship.label,
            if (member.age != null) '${member.age} tahun',
            '${documents.length} dokumen',
          ].join(' · '),
        ),
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
