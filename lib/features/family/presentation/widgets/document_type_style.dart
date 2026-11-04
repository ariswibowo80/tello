import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Icon + color pairing shown for a [FamilyDocument.docType] chip/avatar —
/// purely cosmetic grouping so a glance at the list tells KTP apart from
/// SIM apart from a vehicle document, matching the preset lists in
/// [DocumentTypePresets]. Falls back to a neutral style for any custom
/// (free-text) docType the person typed in themselves.
class DocumentTypeStyle {
  const DocumentTypeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  Color get backgroundColor => color.withValues(alpha: 0.14);

  static DocumentTypeStyle forType(String docType) {
    switch (docType.trim().toLowerCase()) {
      case 'ktp':
        return const DocumentTypeStyle(icon: Icons.badge_rounded, color: AppColors.success);
      case 'kk':
        return const DocumentTypeStyle(icon: Icons.groups_rounded, color: AppColors.primary);
      case 'akta lahir':
        return const DocumentTypeStyle(icon: Icons.description_rounded, color: AppColors.placeAccent);
      case 'paspor':
        return const DocumentTypeStyle(icon: Icons.flight_rounded, color: AppColors.celebrationAccent);
      case 'sim':
        return const DocumentTypeStyle(icon: Icons.directions_car_rounded, color: AppColors.planAccent);
      case 'ijazah':
        return const DocumentTypeStyle(icon: Icons.school_rounded, color: AppColors.placeAccent);
      case 'asuransi':
        return const DocumentTypeStyle(icon: Icons.health_and_safety_rounded, color: AppColors.warning);
      case 'sertifikat':
        return const DocumentTypeStyle(icon: Icons.verified_rounded, color: AppColors.success);
      case 'stnk':
        return const DocumentTypeStyle(icon: Icons.directions_car_filled_rounded, color: AppColors.planAccent);
      case 'bpkb':
        return const DocumentTypeStyle(icon: Icons.menu_book_rounded, color: AppColors.primary);
      case 'pbb':
        return const DocumentTypeStyle(icon: Icons.home_rounded, color: AppColors.success);
      default:
        return const DocumentTypeStyle(icon: Icons.insert_drive_file_rounded, color: AppColors.primary);
    }
  }
}
