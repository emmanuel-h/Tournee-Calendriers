// The part of a street a secteur holds (PLAN §5.15): per side, all, none or
// a range on the integer part of the numbers.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

void main() {
  group('SidePart.range', () {
    test('should keep its bounds when they are house numbers in order', () {
      final side = valueOf(SidePart.range(7, 21)) as NumberRange;

      expect(side.from, 7);
      expect(side.to, 21);
    });

    test('should take a single number, both bounds equal', () {
      expect(valueOf(SidePart.range(9, 9)), range(9, 9));
    });

    test('should take the first and last house numbers as bounds', () {
      final side = valueOf(SidePart.range(0, 99999)) as NumberRange;

      expect((side.from, side.to), (0, 99999));
    });

    for (final (from, to) in [
      (-1, 5),
      (1, -1),
      (100000, 100001),
      (1, 100000),
    ]) {
      test('should refuse $from–$to, a bound out of the numbers', () {
        expect(
          failureOf(SidePart.range(from, to)),
          StreetPartFailure.boundOutOfRange,
        );
      });
    }

    test('should refuse a range whose first bound is after the last', () {
      expect(
        failureOf(SidePart.range(21, 19)),
        StreetPartFailure.reversedRange,
      );
    });

    test('should be equal to a range of the same bounds only', () {
      expect(range(7, 21), range(7, 21));
      expect(range(7, 21).hashCode, range(7, 21).hashCode);
      expect(range(7, 21), isNot(range(7, 23)));
      expect(range(7, 21), isNot(range(5, 21)));
      expect(range(1, 99999), isNot(SidePart.all));
    });

    test('should print its bounds', () {
      expect('${range(7, 21)}', '7–21');
      expect('${SidePart.all}', 'all');
      expect('${SidePart.none}', 'none');
    });
  });

  group('SidePart.holdsNumber', () {
    test('should hold every number when all, none when none', () {
      expect(SidePart.all.holdsNumber(0), isTrue);
      expect(SidePart.all.holdsNumber(99999), isTrue);
      expect(SidePart.none.holdsNumber(0), isFalse);
      expect(SidePart.none.holdsNumber(7), isFalse);
    });

    test('should hold a range from its first to its last bound', () {
      final side = range(7, 21);

      expect(side.holdsNumber(5), isFalse);
      expect(side.holdsNumber(6), isFalse);
      expect(side.holdsNumber(7), isTrue);
      expect(side.holdsNumber(15), isTrue);
      expect(side.holdsNumber(21), isTrue);
      expect(side.holdsNumber(22), isFalse);
      expect(side.holdsNumber(23), isFalse);
    });
  });

  group('SidePart.isWithin', () {
    test('should put none within anything', () {
      expect(SidePart.none.isWithin(SidePart.none), isTrue);
      expect(SidePart.none.isWithin(range(7, 9)), isTrue);
      expect(SidePart.none.isWithin(SidePart.all), isTrue);
    });

    test('should put all within all only', () {
      expect(SidePart.all.isWithin(SidePart.all), isTrue);
      expect(SidePart.all.isWithin(range(1, 99999)), isFalse);
      expect(SidePart.all.isWithin(SidePart.none), isFalse);
    });

    test('should put a range within all, never within none', () {
      expect(range(7, 21).isWithin(SidePart.all), isTrue);
      expect(range(7, 21).isWithin(SidePart.none), isFalse);
    });

    test('should put a range within a range holding both its bounds', () {
      expect(range(7, 21).isWithin(range(7, 21)), isTrue);
      expect(range(9, 19).isWithin(range(7, 21)), isTrue);
      expect(range(5, 21).isWithin(range(7, 21)), isFalse);
      expect(range(7, 23).isWithin(range(7, 21)), isFalse);
    });
  });

  group('StreetPart', () {
    test('should be the whole street by default', () {
      expect(StreetPart.whole.odd, SidePart.all);
      expect(StreetPart.whole.even, SidePart.all);
      expect(StreetPart.whole.isWhole, isTrue);
      expect(StreetPart.whole.isNothing, isFalse);
    });

    test('should keep each side as given', () {
      final created = valueOf(
        StreetPart.create(odd: range(7, 21), even: SidePart.none),
      );

      expect(created.odd, range(7, 21));
      expect(created.even, SidePart.none);
    });

    test('should not be whole when one side is not all', () {
      expect(part(odd: SidePart.all, even: range(2, 30)).isWhole, isFalse);
      expect(part(odd: range(1, 5), even: SidePart.all).isWhole, isFalse);
    });

    test('should be nothing only when both sides are none', () {
      expect(part(odd: SidePart.none, even: SidePart.none).isNothing, isTrue);
      expect(part(odd: SidePart.none, even: range(2, 4)).isNothing, isFalse);
      expect(part(odd: range(1, 3), even: SidePart.none).isNothing, isFalse);
    });

    for (final (odd, even) in [
      (range(6, 21), SidePart.all),
      (range(7, 22), SidePart.all),
      (SidePart.all, range(1, 30)),
      (SidePart.all, range(2, 31)),
    ]) {
      test('should refuse impairs $odd, pairs $even: a bound on the other '
          'side', () {
        expect(
          failureOf(StreetPart.create(odd: odd, even: even)),
          StreetPartFailure.boundOnOtherSide,
        );
      });
    }

    test('should take 0 as a bound of the even side', () {
      expect(
        valueOf(StreetPart.create(odd: SidePart.none, even: range(0, 8))).even,
        range(0, 8),
      );
    });

    test('should hold a number by its side, then by its integer part', () {
      final held = part(odd: range(7, 21), even: range(2, 8));

      expect(held.holds(n('5')), isFalse);
      expect(held.holds(n('7')), isTrue);
      expect(held.holds(n('21bis')), isTrue);
      expect(held.holds(n('23')), isFalse);
      expect(held.holds(n('0')), isFalse);
      expect(held.holds(n('2')), isTrue);
      expect(held.holds(n('8A')), isTrue);
      expect(held.holds(n('10')), isFalse);
    });

    test('should hold nothing of a side that is none', () {
      final evens = part(odd: SidePart.none, even: SidePart.all);

      expect(evens.holds(n('1')), isFalse);
      expect(evens.holds(n('2')), isTrue);
    });

    test('should be within another part only when both sides are', () {
      final held = part(odd: range(7, 21), even: range(2, 30));

      expect(held.isWithin(StreetPart.whole), isTrue);
      expect(held.isWithin(held), isTrue);
      expect(
        held.isWithin(part(odd: range(7, 21), even: range(2, 28))),
        isFalse,
      );
      expect(
        held.isWithin(part(odd: range(9, 21), even: range(2, 30))),
        isFalse,
      );
      expect(StreetPart.whole.isWithin(held), isFalse);
    });

    test('should be equal to a part of the same sides only', () {
      final held = part(odd: range(7, 21), even: SidePart.none);

      expect(held, part(odd: range(7, 21), even: SidePart.none));
      expect(
        held.hashCode,
        part(odd: range(7, 21), even: SidePart.none).hashCode,
      );
      expect(held, isNot(part(odd: range(7, 21), even: SidePart.all)));
      expect(held, isNot(part(odd: range(7, 23), even: SidePart.none)));
      expect(StreetPart.whole, part(odd: SidePart.all, even: SidePart.all));
    });

    test('should print both sides', () {
      expect(
        '${part(odd: range(7, 21), even: SidePart.none)}',
        'StreetPart(odd: 7–21, even: none)',
      );
    });
  });
}
