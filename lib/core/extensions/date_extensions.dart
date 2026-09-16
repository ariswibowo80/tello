import 'package:intl/intl.dart';

extension DateFormatting on DateTime {
  /// e.g. "15 Aug"
  String get dayMonth => DateFormat('d MMM').format(this);

  /// e.g. "15–17 August 2026" when [end] is provided and differs, or
  /// "15 August 2026" for a single-day event.
  String rangeLabel(DateTime? end) {
    final full = DateFormat('d MMMM yyyy');
    if (end == null || _isSameDay(end)) return full.format(this);
    if (year == end.year && month == end.month) {
      return '${DateFormat('d').format(this)}–${DateFormat('d MMMM yyyy').format(end)}';
    }
    return '${full.format(this)} – ${full.format(end)}';
  }

  bool _isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// e.g. "19 days to go", "Today", "3 days ago"
  String get countdownLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(year, month, day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff > 0) return '$diff ${diff == 1 ? 'day' : 'days'} to go';
    final ago = -diff;
    return '$ago ${ago == 1 ? 'day' : 'days'} ago';
  }
}
