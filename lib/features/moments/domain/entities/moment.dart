import 'package:cloud_firestore/cloud_firestore.dart';

class GeoLocation {
  const GeoLocation({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.placeId,
  });

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Google Places place_id, when this location came from Places
  /// Autocomplete rather than reverse geocoding / manual entry. Lets the
  /// Google Maps link point at the exact place instead of just coordinates.
  final String? placeId;

  factory GeoLocation.fromMap(Map<String, dynamic> map) => GeoLocation(
        name: map['name'] as String? ?? '',
        address: map['address'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        placeId: map['placeId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'placeId': placeId,
      };
}

enum MediaType { image, video }

class MediaItem {
  const MediaItem({
    required this.url,
    required this.storagePath,
    required this.type,
    this.thumbnailUrl,
    this.thumbnailStoragePath,
    this.createdAt,
  });

  final String url;
  final String storagePath;
  final MediaType type;
  final String? thumbnailUrl;

  /// Storage path of the compressed thumbnail, if one was generated.
  /// Needed so deleting a Moment/Plan can clean up both files, not just
  /// the full-size image (thumbnailUrl alone isn't enough to build a
  /// Storage reference back).
  final String? thumbnailStoragePath;
  final DateTime? createdAt;

  factory MediaItem.fromMap(Map<String, dynamic> map) => MediaItem(
        url: map['url'] as String? ?? '',
        storagePath: map['storagePath'] as String? ?? '',
        type: (map['type'] as String?) == 'video' ? MediaType.video : MediaType.image,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        thumbnailStoragePath: map['thumbnailStoragePath'] as String?,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'storagePath': storagePath,
        'type': type.name,
        'thumbnailUrl': thumbnailUrl,
        'thumbnailStoragePath': thumbnailStoragePath,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };
}

/// A completed, permanent life event. Moments are immutable in spirit —
/// edits are allowed, but a Moment is never "in progress" the way a Plan is.
class Moment {
  const Moment({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.location,
    this.peopleIds = const [],
    this.media = const [],
    this.tags = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.sourcePlanId,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final GeoLocation? location;
  final List<String> peopleIds;
  final List<MediaItem> media;
  final List<String> tags;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Non-null when this Moment was created via the Plan → Moment flow.
  final String? sourcePlanId;

  factory Moment.fromFirestore(String id, Map<String, dynamic> map) {
    return Moment(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      location: map['location'] != null
          ? GeoLocation.fromMap(Map<String, dynamic>.from(map['location'] as Map))
          : null,
      peopleIds: List<String>.from(map['peopleIds'] as List? ?? const []),
      media: (map['media'] as List? ?? const [])
          .map((m) => MediaItem.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      tags: List<String>.from(map['tags'] as List? ?? const []),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      sourcePlanId: map['sourcePlanId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'location': location?.toMap(),
        'peopleIds': peopleIds,
        'media': media.map((m) => m.toMap()).toList(),
        'tags': tags,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'sourcePlanId': sourcePlanId,
        // Denormalized for the "On This Day" query — Firestore can't
        // extract month/day from a Timestamp in a query, so this lets
        // `where('monthDay', isEqualTo: ...)` find same-day-across-years
        // Moments without fetching and filtering the whole collection.
        'monthDay': monthDayKey(startDate),
      };

  /// e.g. DateTime(2026, 8, 5) -> '08-05'. Used both when writing a
  /// Moment (see [toFirestore]) and when querying "on this day".
  static String monthDayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  Moment copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    GeoLocation? location,
    List<String>? peopleIds,
    List<MediaItem>? media,
    List<String>? tags,
    String? notes,
    bool clearNotes = false,
  }) {
    return Moment(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      peopleIds: peopleIds ?? this.peopleIds,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      sourcePlanId: sourcePlanId,
    );
  }
}
