import 'package:flutter_test/flutter_test.dart';
import 'package:tello/features/people/domain/entities/person.dart';

void main() {
  group('Person.initials', () {
    test('single name returns one letter', () {
      const person = Person(id: '1', name: 'Mama');
      expect(person.initials, 'M');
    });

    test('two-part name returns first + last initials', () {
      const person = Person(id: '2', name: 'Budi Santoso');
      expect(person.initials, 'BS');
    });

    test('collapses extra whitespace between name parts', () {
      const person = Person(id: '3', name: '  Budi   Santoso  ');
      expect(person.initials, 'BS');
    });

    test('falls back to "?" for an empty name', () {
      const person = Person(id: '4', name: '');
      expect(person.initials, '?');
    });
  });
}
