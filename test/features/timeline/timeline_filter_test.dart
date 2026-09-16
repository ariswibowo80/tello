import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/timeline/domain/entities/timeline_filter.dart';

void main() {
  group('TimelineFilter equality', () {
    test('two "all" instances are equal', () {
      expect(TimelineFilter.all, TimelineFilter.all);
    });

    test('two tag filters with the same tag are equal', () {
      expect(TimelineFilter.customTag('travel'), TimelineFilter.customTag('travel'));
    });

    test('tag filters with different tags are not equal', () {
      expect(TimelineFilter.customTag('travel') == TimelineFilter.customTag('work'), isFalse);
    });

    test('a built-in tag filter matches an equivalent custom tag', () {
      final builtIn = TimelineFilter.builtInTagFilters.firstWhere((f) => f.tag == 'family');
      expect(builtIn, TimelineFilter.customTag('family'));
    });

    test('defaults list has one entry per built-in filter plus all/moments/plans', () {
      expect(TimelineFilter.defaults.length, 3 + TimelineFilter.builtInTagFilters.length);
    });
  });
}
