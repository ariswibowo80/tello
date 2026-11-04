import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AssetCategory { house, vehicle, land, electronics, jewelry, other }

extension AssetCategoryX on AssetCategory {
  String get label => switch (this) {
        AssetCategory.house => 'Rumah',
        AssetCategory.vehicle => 'Kendaraan',
        AssetCategory.land => 'Tanah',
        AssetCategory.electronics => 'Elektronik',
        AssetCategory.jewelry => 'Perhiasan',
        AssetCategory.other => 'Lainnya',
      };

  IconData get icon => switch (this) {
        AssetCategory.house => Icons.house_rounded,
        AssetCategory.vehicle => Icons.directions_car_rounded,
        AssetCategory.land => Icons.terrain_rounded,
        AssetCategory.electronics => Icons.devices_rounded,
        AssetCategory.jewelry => Icons.diamond_rounded,
        AssetCategory.other => Icons.inventory_2_rounded,
      };
}

/// A family-owned asset (house, car, land, ...) that owns a `documents`
/// subcollection for its paperwork (sertifikat, STNK, BPKB, polis
/// asuransi, ...). Scoped to the household, like Moments/Plans.
class FamilyAsset {
  const FamilyAsset({
    required this.id,
    required this.name,
    required this.category,
    this.purchaseDate,
    this.estimatedValue,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AssetCategory category;
  final DateTime? purchaseDate;
  final double? estimatedValue;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyAsset.fromFirestore(String id, Map<String, dynamic> map) {
    return FamilyAsset(
      id: id,
      name: map['name'] as String? ?? '',
      category: AssetCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => AssetCategory.other,
      ),
      purchaseDate: (map['purchaseDate'] as Timestamp?)?.toDate(),
      estimatedValue: (map['estimatedValue'] as num?)?.toDouble(),
      photoUrl: map['photoUrl'] as String?,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'category': category.name,
        'purchaseDate': purchaseDate != null ? Timestamp.fromDate(purchaseDate!) : null,
        'estimatedValue': estimatedValue,
        'photoUrl': photoUrl,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  FamilyAsset copyWith({
    String? name,
    AssetCategory? category,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    double? estimatedValue,
    bool clearEstimatedValue = false,
    String? photoUrl,
    String? notes,
    bool clearNotes = false,
  }) {
    return FamilyAsset(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      purchaseDate: clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
      estimatedValue: clearEstimatedValue ? null : (estimatedValue ?? this.estimatedValue),
      photoUrl: photoUrl ?? this.photoUrl,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
