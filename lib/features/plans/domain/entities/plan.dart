import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../moments/domain/entities/moment.dart';

/// Non-terminal statuses — "what's still ahead" for a plan. Shared by the
/// Timeline's Plans filter and the dedicated Plans tab so both agree on
/// what counts as "upcoming".
const List<PlanStatus> activePlanStatuses = [
  PlanStatus.idea,
  PlanStatus.planning,
  PlanStatus.confirmed,
  PlanStatus.ongoing,
];

extension PlanStatusLabel on PlanStatus {
  String get label {
    switch (this) {
      case PlanStatus.idea:
        return 'Idea';
      case PlanStatus.planning:
        return 'Planning';
      case PlanStatus.confirmed:
        return 'Confirmed';
      case PlanStatus.ongoing:
        return 'Ongoing';
      case PlanStatus.completed:
        return 'Completed';
      case PlanStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class ChecklistItem {
  const ChecklistItem({required this.id, required this.title, this.isDone = false});

  final String id;
  final String title;
  final bool isDone;

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        isDone: map['isDone'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'isDone': isDone};

  ChecklistItem copyWith({String? title, bool? isDone}) => ChecklistItem(
        id: id,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
      );
}

class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.date,
    this.time,
    required this.title,
    this.location,
    this.notes,
  });

  final String id;
  final DateTime date;
  final String? time;
  final String title;
  final GeoLocation? location;
  final String? notes;

  factory ItineraryItem.fromMap(Map<String, dynamic> map) => ItineraryItem(
        id: map['id'] as String? ?? '',
        date: (map['date'] as Timestamp).toDate(),
        time: map['time'] as String?,
        title: map['title'] as String? ?? '',
        location: map['location'] != null
            ? GeoLocation.fromMap(Map<String, dynamic>.from(map['location'] as Map))
            : null,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': Timestamp.fromDate(date),
        'time': time,
        'title': title,
        'location': location?.toMap(),
        'notes': notes,
      };
}

class Budget {
  const Budget({this.estimated, this.actual, this.currency = 'IDR'});

  final double? estimated;
  final double? actual;
  final String currency;

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        estimated: (map['estimatedBudget'] as num?)?.toDouble(),
        actual: (map['actualBudget'] as num?)?.toDouble(),
        currency: map['currency'] as String? ?? 'IDR',
      );

  Map<String, dynamic> toMap() => {
        'estimatedBudget': estimated,
        'actualBudget': actual,
        'currency': currency,
      };
}

class Plan {
  const Plan({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.startDate,
    this.endDate,
    this.status = PlanStatus.idea,
    this.location,
    this.peopleIds = const [],
    this.checklist = const [],
    this.itinerary = const [],
    this.budget,
    this.media = const [],
    this.links = const [],
    this.tags = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.convertedToMomentId,
  });

  final String id;
  final String title;
  final String? description;
  final PlanCategory category;
  final DateTime startDate;
  final DateTime? endDate;
  final PlanStatus status;
  final GeoLocation? location;
  final List<String> peopleIds;
  final List<ChecklistItem> checklist;
  final List<ItineraryItem> itinerary;
  final Budget? budget;
  final List<MediaItem> media;

  /// Inspiration links ("Inspiration: Allow photos and links.") — plain
  /// URLs, shown alongside [media] on Plan Detail.
  final List<String> links;
  final List<String> tags;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? convertedToMomentId;

  /// Fraction of checklist items completed, used by ProgressIndicator /
  /// CountdownCard widgets. Returns 0 when there's no checklist yet.
  double get progress {
    if (checklist.isEmpty) return 0;
    final done = checklist.where((i) => i.isDone).length;
    return done / checklist.length;
  }

  int get daysUntilStart => startDate.difference(DateTime.now()).inDays;

  factory Plan.fromFirestore(String id, Map<String, dynamic> map) {
    return Plan(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      category: PlanCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => PlanCategory.other,
      ),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      status: PlanStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PlanStatus.idea,
      ),
      location: map['location'] != null
          ? GeoLocation.fromMap(Map<String, dynamic>.from(map['location'] as Map))
          : null,
      peopleIds: List<String>.from(map['peopleIds'] as List? ?? const []),
      checklist: (map['checklist'] as List? ?? const [])
          .map((i) => ChecklistItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      itinerary: (map['itinerary'] as List? ?? const [])
          .map((i) => ItineraryItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      budget: (map['estimatedBudget'] != null || map['actualBudget'] != null)
          ? Budget.fromMap(map)
          : null,
      media: (map['media'] as List? ?? const [])
          .map((m) => MediaItem.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      links: List<String>.from(map['links'] as List? ?? const []),
      tags: List<String>.from(map['tags'] as List? ?? const []),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      convertedToMomentId: map['convertedToMomentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'category': category.name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'status': status.name,
        'location': location?.toMap(),
        'peopleIds': peopleIds,
        'checklist': checklist.map((c) => c.toMap()).toList(),
        'itinerary': itinerary.map((i) => i.toMap()).toList(),
        if (budget != null) ...budget!.toMap(),
        'media': media.map((m) => m.toMap()).toList(),
        'links': links,
        'tags': tags,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'convertedToMomentId': convertedToMomentId,
      };

  Plan copyWith({
    String? title,
    String? description,
    PlanCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    PlanStatus? status,
    GeoLocation? location,
    List<String>? peopleIds,
    List<ChecklistItem>? checklist,
    List<ItineraryItem>? itinerary,
    Budget? budget,
    List<MediaItem>? media,
    List<String>? links,
    List<String>? tags,
    String? notes,
    bool clearNotes = false,
  }) {
    return Plan(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      location: location ?? this.location,
      peopleIds: peopleIds ?? this.peopleIds,
      checklist: checklist ?? this.checklist,
      itinerary: itinerary ?? this.itinerary,
      budget: budget ?? this.budget,
      media: media ?? this.media,
      links: links ?? this.links,
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      completedAt: completedAt,
      convertedToMomentId: convertedToMomentId,
    );
  }

  /// Builds the draft Moment carried over when converting this Plan,
  /// per the "Plan → Moment" spec: title, date, location, people,
  /// itinerary/notes, photos, tags, places all carry over.
  Moment toMomentDraft({required String story}) {
    final now = DateTime.now();
    final trimmedStory = story.trim();
    return Moment(
      id: '', // assigned by the repository
      title: title,
      description: trimmedStory.isEmpty ? null : trimmedStory,
      startDate: startDate,
      endDate: endDate,
      location: location,
      peopleIds: peopleIds,
      media: media,
      tags: tags,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      sourcePlanId: id,
    );
  }
}
