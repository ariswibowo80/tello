import 'package:flutter_test/flutter_test.dart';
import 'package:tello/core/extensions/date_extensions.dart';

void main() {
  group('countdownLabel', () {
    test('returns "Today" for the current date', () {
      final today = DateTime.now();
      expect(today.countdownLabel, 'Today');
    });

    test('returns "N days to go" for a future date', () {
      final future = DateTime.now().add(const Duration(days: 19));
      expect(future.countdownLabel, '19 days to go');
    });

    test('returns "1 day to go" (singular) for tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(tomorrow.countdownLabel, '1 day to go');
    });

    test('returns "N days ago" for a past date', () {
      final past = DateTime.now().subtract(const Duration(days: 3));
      expect(past.countdownLabel, '3 days ago');
    });
  });

  group('rangeLabel', () {
    test('formats a single-day event without a range', () {
      final date = DateTime(2026, 8, 15);
      expect(date.rangeLabel(null), '15 August 2026');
    });

    test('formats a same-month range compactly', () {
      final start = DateTime(2026, 9, 20);
      final end = DateTime(2026, 9, 24);
      expect(start.rangeLabel(end), '20–24 September 2026');
    });

    test('formats a cross-month range with both full dates', () {
      final start = DateTime(2026, 8, 30);
      final end = DateTime(2026, 9, 2);
      expect(start.rangeLabel(end), '30 August 2026 – 2 September 2026');
    });
  });
}
