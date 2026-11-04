import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum FamilyRelationship { spouse, child, parent, sibling, other }

extension FamilyRelationshipX on FamilyRelationship {
  String get label => switch (this) {
        FamilyRelationship.spouse => 'Pasangan',
        FamilyRelationship.child => 'Anak',
        FamilyRelationship.parent => 'Orang Tua',
        FamilyRelationship.sibling => 'Saudara',
        FamilyRelationship.other => 'Lainnya',
      };

  IconData get icon => switch (this) {
        FamilyRelationship.spouse => Icons.favorite_rounded,
        FamilyRelationship.child => Icons.child_care_rounded,
        FamilyRelationship.parent => Icons.elderly_rounded,
        FamilyRelationship.sibling => Icons.people_rounded,
        FamilyRelationship.other => Icons.person_rounded,
      };
}

/// A full family-member profile — distinct from the lightweight `Person`
/// used to tag "who was there" on Moments/Plans. This one carries the
/// richer data (birth date, notes) and owns a `documents` subcollection
/// for personal documents (KTP, KK, akta lahir, ...).
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    this.birthDate,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final FamilyRelationship relationship;
  final DateTime? birthDate;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Age in whole years as of today, or null if [birthDate] isn't set.
  int? get age {
    final dob = birthDate;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory FamilyMember.fromFirestore(String id, Map<String, dynamic> map) {
    return FamilyMember(
      id: id,
      name: map['name'] as String? ?? '',
      relationship: FamilyRelationship.values.firstWhere(
        (r) => r.name == map['relationship'],
        orElse: () => FamilyRelationship.other,
      ),
      birthDate: (map['birthDate'] as Timestamp?)?.toDate(),
      photoUrl: map['photoUrl'] as String?,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'relationship': relationship.name,
        'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
        'photoUrl': photoUrl,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  FamilyMember copyWith({
    String? name,
    FamilyRelationship? relationship,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? photoUrl,
    String? notes,
    bool clearNotes = false,
  }) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      photoUrl: photoUrl ?? this.photoUrl,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
