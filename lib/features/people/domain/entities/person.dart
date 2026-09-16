import 'package:cloud_firestore/cloud_firestore.dart';

/// A person the user can tag in Moments/Plans ("Who was there?").
/// Deliberately lightweight for MVP — no relationship graph, just enough
/// to give people a name (and later, a photo) to select from.
class Person {
  const Person({
    required this.id,
    required this.name,
    this.photoUrl,
    this.relationship,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String? relationship;

  factory Person.fromFirestore(String id, Map<String, dynamic> map) => Person(
        id: id,
        name: map['name'] as String? ?? '',
        photoUrl: map['photoUrl'] as String?,
        relationship: map['relationship'] as String?,
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'photoUrl': photoUrl,
        'relationship': relationship,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Used for the fallback initials shown in [PersonAvatar].
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
