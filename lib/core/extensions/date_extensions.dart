import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension TimeOfDayFormatting on TimeOfDay {
  /// e.g. "14:05" - always 24-hour, regardless of device locale or the
  /// system's 12h/24h setting. Moments should show one consistent
  /// format for everyone in the household.
  String get hhmm => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

extension DateFormatting on DateTime {
  /// e.g. "15 Aug"
  String get dayMonth => DateFormat('d MMM').format(this);

  /// True when this DateTime carries a real time-of-day rather than the
  /// midnight default left by a date-only picker. Used to decide whether
  /// to show a time alongside a date (e.g. on MomentCard) or hide it.
  bool get hasTimeSet => hour != 0 || minute != 0;

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
