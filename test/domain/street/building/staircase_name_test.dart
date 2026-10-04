import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';

void main() {
  test('should keep its letter when it is one capital letter', () {
    expect(StaircaseName('B').letter, 'B');
  });

  final refused = {
    'empty': '',
    'lowercase': 'a',
    'two letters': 'AB',
    'a digit': '1',
    'an accented letter': 'É',
    'a space around': ' A',
  };
  refused.forEach((what, letter) {
    test('should refuse $what', () {
      expect(() => StaircaseName(letter), throwsArgumentError);
    });
  });

  group('at', () {
    test('should name the first staircase A', () {
      expect(StaircaseName.at(0), StaircaseName('A'));
    });

    test('should name the second staircase B', () {
      expect(StaircaseName.at(1), StaircaseName('B'));
    });

    test('should name the last staircase Z', () {
      expect(StaircaseName.at(StaircaseName.maxCount - 1), StaircaseName('Z'));
    });

    test('should refuse a position after Z', () {
      expect(
        () => StaircaseName.at(StaircaseName.maxCount),
        throwsArgumentError,
      );
    });

    test('should refuse a position before A', () {
      expect(() => StaircaseName.at(-1), throwsArgumentError);
    });
  });

  test('should allow 26 staircases, one per letter', () {
    expect(StaircaseName.maxCount, 26);
  });

  test('should be equal when the letters are equal', () {
    expect(StaircaseName('A'), StaircaseName('A'));
    expect(StaircaseName('A').hashCode, StaircaseName('A').hashCode);
  });

  test('should differ when the letters differ', () {
    expect(StaircaseName('A'), isNot(StaircaseName('B')));
  });

  test('should show its letter when printed', () {
    expect(StaircaseName('C').toString(), 'StaircaseName(C)');
  });
}
