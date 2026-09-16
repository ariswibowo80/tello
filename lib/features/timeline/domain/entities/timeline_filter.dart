/// Built-in timeline filters. `all` and `momentsOnly` both render the
/// Moments list (optionally narrowed by [tag]); `plansOnly` swaps the body
/// to a full Plans list instead. Category filters (family, travel, ...)
/// are just Moment tag filters under the hood.
enum TimelineFilterKind { all, momentsOnly, plansOnly, tag }

class TimelineFilter {
  const TimelineFilter._(this.kind, this.tag, this.label);

  final TimelineFilterKind kind;
  final String? tag;
  final String label;

  static const all = TimelineFilter._(TimelineFilterKind.all, null, 'All');
  static const moments = TimelineFilter._(TimelineFilterKind.momentsOnly, null, 'Moments');
  static const plans = TimelineFilter._(TimelineFilterKind.plansOnly, null, 'Plans');

  static const builtInTagFilters = [
    TimelineFilter._(TimelineFilterKind.tag, 'family', 'Family'),
    TimelineFilter._(TimelineFilterKind.tag, 'travel', 'Travel'),
    TimelineFilter._(TimelineFilterKind.tag, 'work', 'Work'),
    TimelineFilter._(TimelineFilterKind.tag, 'celebration', 'Celebration'),
    TimelineFilter._(TimelineFilterKind.tag, 'school', 'School'),
    TimelineFilter._(TimelineFilterKind.tag, 'personal', 'Personal'),
  ];

  factory TimelineFilter.customTag(String tag) =>
      TimelineFilter._(TimelineFilterKind.tag, tag, tag);

  static const List<TimelineFilter> defaults = [all, moments, plans, ...builtInTagFilters];

  @override
  bool operator ==(Object other) =>
      other is TimelineFilter && other.kind == kind && other.tag == tag;

  @override
  int get hashCode => Object.hash(kind, tag);
}

enum TimelineSort { newest, oldest }
