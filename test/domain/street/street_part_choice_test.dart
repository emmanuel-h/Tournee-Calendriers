import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// A street of Villefranche-sur-Saône running east along the 45.98°
// parallel. House k of a side stands 1e-4° of longitude (about 7.7 m)
// further east than house k - 1: the odd numbers 1, 3 … 11 a little north
// of the road, the even 2, 4 … 12 a little south. 3bis stands with 3; 13
// has no position (typed by hand).

/// The longitude of the [k]-th house of a side (from 0).
double _lon(int k) => 4.7200 + k * 0.0001;

GeoPoint _oddDoor(int k) => at(45.98005, _lon(k));
GeoPoint _evenDoor(int k) => at(45.97995, _lon(k));

final _road = StreetShape([
  [at(45.98, 4.7195), at(45.98, 4.7212)],
]);

final _numbers = [
  for (var k = 0; k < 6; k++)
    PartNumber(n('${2 * k + 1}'), position: _oddDoor(k)),
  for (var k = 0; k < 6; k++)
    PartNumber(n('${2 * k + 2}'), position: _evenDoor(k)),
  PartNumber(n('3bis'), position: _oddDoor(1)),
  PartNumber(n('13')),
];

StreetPartChoice _choice({
  StreetPart part = StreetPart.whole,
  List<PartNumber>? numbers,
  StreetShape? road,
}) => StreetPartChoice.start(
  numbers: numbers ?? _numbers,
  road: road ?? _road,
  part: part,
);

StreetPartChoice _odd({StreetPart part = StreetPart.whole}) =>
    _choice(part: part).withSide(Sides.odd);

List<String> _labels(Iterable<PartDot> dots) => [
  for (final dot in dots) dot.number.label,
];

void main() {
  group('start', () {
    test('should sort the numbers and keep each once, with its first '
        'position', () {
      final choice = _choice(
        numbers: [
          PartNumber(n('5'), position: _oddDoor(2)),
          PartNumber(n('1'), position: _oddDoor(0)),
          PartNumber(n('5'), position: _oddDoor(4)),
        ],
      );

      expect(choice.numbers, [
        PartNumber(n('1'), position: _oddDoor(0)),
        PartNumber(n('5'), position: _oddDoor(2)),
      ]);
    });

    test('should show both sides, the part given, and count its numbers', () {
      final choice = _choice(
        part: part(odd: range(3, 7), even: SidePart.none),
      );

      expect(choice.side, Sides.both);
      expect(choice.part, part(odd: range(3, 7), even: SidePart.none));
      // 3, 3bis, 5, 7 of 14.
      expect(choice.keptCount, 4);
      expect(choice.numberCount, 14);
    });

    test('should name the lowest and the highest numbers of the street', () {
      final choice = _choice();

      expect(choice.lowest, 1);
      expect(choice.highest, 13);
    });

    test('should name no lowest or highest number for a street without '
        'numbers', () {
      final choice = _choice(numbers: []);

      expect(choice.lowest, isNull);
      expect(choice.highest, isNull);
    });

    test('should put the marks around every dot when the whole street is '
        'held', () {
      final choice = _choice();

      // 12 dots along the road (3bis with 3): 13 places.
      expect(choice.first, 0);
      expect(choice.last, 12);
    });

    test('should put the marks together at the start when the part keeps no '
        'dot', () {
      final choice = _choice(
        part: part(odd: SidePart.none, even: SidePart.none),
      );

      expect(choice.first, 0);
      expect(choice.last, 0);
    });
  });

  group('drawing', () {
    test('should be none for a street without positions', () {
      final choice = _choice(numbers: [PartNumber(n('1')), PartNumber(n('2'))]);

      expect(choice.drawing, isNull);
    });

    test('should be none for a street with neither road nor two places', () {
      final choice = _choice(
        road: StreetShape.none,
        numbers: [
          PartNumber(n('1'), position: _oddDoor(0)),
          PartNumber(n('1bis'), position: _oddDoor(0)),
        ],
      );

      expect(choice.drawing, isNull);
    });

    test('should draw a straight road between the two dots farthest apart '
        'when the road is not known', () {
      final choice = _choice(
        road: StreetShape.none,
        numbers: [
          PartNumber(n('1'), position: _oddDoor(0)),
          PartNumber(n('3'), position: _oddDoor(1)),
          PartNumber(n('5'), position: _oddDoor(2)),
        ],
      );

      expect(
        choice.drawing!.road,
        StreetShape([
          [_oddDoor(0), _oddDoor(2)],
        ]),
      );
    });

    test('should draw the road given', () {
      expect(_choice().drawing!.road, _road);
    });

    test('should draw a dot per number with a position, by number, kept or '
        'left out', () {
      final drawing = _choice(
        part: part(odd: range(3, 5), even: SidePart.all),
      ).drawing!;

      expect(_labels(drawing.dots), [
        '1',
        '2',
        '3',
        '3bis',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        '11',
        '12', //
      ]);
      expect(
        drawing.dots.first,
        PartDot(
          number: n('1'),
          position: _oddDoor(0),
          look: PartDotLook.leftOut,
        ),
      );
      expect(drawing.dots[1].look, PartDotLook.kept);
      expect(drawing.dots[2].look, PartDotLook.kept);
      expect(drawing.dots[7].look, PartDotLook.leftOut);
    });

    test('should grey the dots of the other side than the one shown', () {
      final drawing = _odd().drawing!;

      expect(
        _labels(drawing.dots.where((dot) => dot.look == PartDotLook.otherSide)),
        ['2', '4', '6', '8', '10', '12'],
      );
      expect(
        _labels(drawing.dots.where((dot) => dot.look == PartDotLook.kept)),
        ['1', '3', '3bis', '5', '7', '9', '11'],
      );
    });

    test('should give a place before the first dot, between each two and '
        'after the last, along the road', () {
      final drawing = _odd().drawing!;

      expect(drawing.gaps, hasLength(7));
      // Between 1 and 3: half way, on the road.
      expect(drawing.gaps[1].latitude, closeTo(45.98, 1e-9));
      expect(drawing.gaps[1].longitude, closeTo(_lon(0) + 0.00005, 1e-9));
      // Before 1 and after 11: 8 m beyond, about 1.04e-4°.
      expect(drawing.gaps[0].longitude, lessThan(_lon(0) - 0.0001));
      expect(drawing.gaps[0].longitude, greaterThan(_lon(0) - 0.00011));
      expect(drawing.gaps[6].longitude, greaterThan(_lon(5) + 0.0001));
    });

    test('should name the places of the marks by the dots around them', () {
      final drawing = _odd(
        part: part(odd: range(5, 9), even: SidePart.all),
      ).drawing!;

      expect(drawing.first!.gap, 2);
      expect(drawing.first!.place, const MarkBetween(3, 5));
      expect(drawing.first!.point, drawing.gaps[2]);
      expect(drawing.last!.gap, 5);
      expect(drawing.last!.place, const MarkBetween(9, 11));
    });

    test('should name the places at the ends by the first and last dots', () {
      final drawing = _odd().drawing!;

      expect(drawing.first!.place, const MarkBefore(1));
      expect(drawing.last!.place, const MarkAfter(11));
    });

    test('should draw the stretch between the marks as kept', () {
      final drawing = _odd(
        part: part(odd: range(5, 9), even: SidePart.all),
      ).drawing!;

      final kept = drawing.kept.lines.single;
      expect(kept.first.longitude, closeTo(_lon(1) + 0.00005, 1e-9));
      expect(kept.last.longitude, closeTo(_lon(4) + 0.00005, 1e-9));
    });

    test('should draw no stretch when the marks meet', () {
      final drawing = _odd(
        part: part(odd: SidePart.none, even: SidePart.all),
      ).drawing!;

      expect(drawing.kept, StreetShape.none);
    });

    test('should draw no mark on a side without dots', () {
      final drawing = _choice(
        numbers: [
          PartNumber(n('1'), position: _oddDoor(0)),
          PartNumber(n('2')),
        ],
      ).withSide(Sides.even).drawing!;

      expect(drawing.gaps, isEmpty);
      expect(drawing.first, isNull);
      expect(drawing.last, isNull);
      expect(drawing.kept, StreetShape.none);
    });

    test('should show the dots and the road around them, not the whole '
        'road', () {
      final area = _choice().drawing!.area;

      // The road runs from 4.7195 to 4.7212; the dots from 4.7200 to 4.7205.
      expect(area.west, greaterThan(4.7195));
      expect(area.west, lessThan(_lon(0)));
      expect(area.east, lessThan(4.7212));
      expect(area.east, greaterThan(_lon(5)));
      expect(area.north, 45.98005);
      expect(area.south, 45.97995);
    });

    test('should order two dots at the same place along the road by '
        'number', () {
      final drawing = _choice(
        numbers: [
          PartNumber(n('4'), position: _evenDoor(0)),
          PartNumber(n('3'), position: _oddDoor(0)),
          PartNumber(n('5'), position: _oddDoor(1)),
        ],
      ).drawing!;

      expect(drawing.first!.place, const MarkBefore(3));
      expect(
        _choice().withMark(PartMark.first, 1).drawing!.first!.place,
        const MarkBetween(1, 2),
      );
    });
  });

  group('withMark on one side', () {
    test('should keep the side from the first dot after the first mark, to '
        'the last number of the side when the last mark is at the end', () {
      final choice = _odd().withMark(PartMark.first, 2);

      // 13 has no dot, and is the highest odd number.
      expect(choice.part, part(odd: range(5, 13), even: SidePart.all));
      expect(choice.first, 2);
      expect(choice.last, 6);
    });

    test('should keep the numbers between two marks inside the street', () {
      final choice = _odd()
          .withMark(PartMark.first, 2)
          .withMark(PartMark.last, 4);

      expect(choice.part, part(odd: range(5, 7), even: SidePart.all));
    });

    test('should start from the lowest number of the side when the first '
        'mark is at the start', () {
      final choice = _odd().withMark(PartMark.last, 3);

      expect(choice.part, part(odd: range(1, 5), even: SidePart.all));
    });

    test('should keep the whole side when the marks are back at the ends', () {
      final choice = _odd(
        part: part(odd: range(5, 7), even: SidePart.none),
      ).withMark(PartMark.first, 0).withMark(PartMark.last, 6);

      expect(choice.part, part(odd: SidePart.all, even: SidePart.none));
    });

    test('should keep nothing of the side when the marks meet', () {
      final choice = _odd(
        part: part(odd: range(5, 7), even: SidePart.all),
      ).withMark(PartMark.last, 2);

      expect(choice.part, part(odd: SidePart.none, even: SidePart.all));
      expect(choice.first, 2);
      expect(choice.last, 2);
    });

    test('should stop the first mark at the last', () {
      final choice = _odd(
        part: part(odd: range(3, 5), even: SidePart.all),
      ).withMark(PartMark.first, 5);

      expect(choice.first, 3);
      expect(choice.last, 3);
    });

    test('should stop the last mark at the first', () {
      final choice = _odd(
        part: part(odd: range(5, 7), even: SidePart.all),
      ).withMark(PartMark.last, 0);

      expect(choice.first, 2);
      expect(choice.last, 2);
    });

    test('should keep the marks within their places', () {
      final choice = _odd(
        part: part(odd: range(5, 7), even: SidePart.all),
      ).withMark(PartMark.last, 40).withMark(PartMark.first, -3);

      expect(choice.first, 0);
      expect(choice.last, 6);
    });

    test('should change nothing when the mark stays where it is', () {
      final choice = _odd();

      expect(choice.withMark(PartMark.last, 6), same(choice));
    });

    test('should take 3bis with 3', () {
      final choice = _odd().withMark(PartMark.first, 1);

      expect(choice.part, part(odd: range(3, 13), even: SidePart.all));
      expect(choice.keptCount, 13);
    });
  });

  group('withMark on both sides', () {
    test('should cut both sides at once', () {
      // Along the road: 1 2 3 4 5 6 7 8 … (each odd a hair before its even
      // neighbour, by number). Places 4 and 8: from 5 to 8.
      final choice = _choice()
          .withMark(PartMark.first, 4)
          .withMark(PartMark.last, 8);

      expect(choice.part, part(odd: range(5, 7), even: range(6, 8)));
    });

    test('should keep the part of a side without dots', () {
      final choice = _choice(
        part: part(odd: SidePart.all, even: range(2, 4)),
        numbers: [
          PartNumber(n('1'), position: _oddDoor(0)),
          PartNumber(n('3'), position: _oddDoor(1)),
          PartNumber(n('5'), position: _oddDoor(2)),
          PartNumber(n('2')),
          PartNumber(n('4')),
        ],
      ).withMark(PartMark.first, 1);

      expect(choice.part, part(odd: range(3, 5), even: range(2, 4)));
    });
  });

  group('withSide', () {
    test('should put the marks around the dots of the side the part keeps', () {
      final choice = _choice(
        part: part(odd: range(5, 9), even: range(2, 4)),
      ).withSide(Sides.even);

      expect(choice.side, Sides.even);
      expect(choice.first, 0);
      expect(choice.last, 2);
    });
  });

  group('holdingAll and holdingNothing', () {
    final cut = part(odd: range(5, 9), even: range(2, 4));

    test('should hold the whole street on both sides', () {
      final choice = _choice(part: cut).holdingAll();

      expect(choice.part, StreetPart.whole);
      expect(choice.first, 0);
      expect(choice.last, 12);
    });

    test('should hold nothing on both sides', () {
      expect(
        _choice(part: cut).holdingNothing().part,
        part(odd: SidePart.none, even: SidePart.none),
      );
    });

    test('should hold every odd number, the even side as it was', () {
      expect(
        _choice(part: cut).withSide(Sides.odd).holdingAll().part,
        part(odd: SidePart.all, even: range(2, 4)),
      );
    });

    test('should hold no even number, the odd side as it was', () {
      expect(
        _choice(part: cut).withSide(Sides.even).holdingNothing().part,
        part(odd: range(5, 9), even: SidePart.none),
      );
    });
  });

  group('withBounds', () {
    final noMap = [
      for (final number in ['1', '3', '5', '7', '2', '4', '6'])
        PartNumber(n(number)),
    ];
    StreetPartChoice manual(Sides side) => StreetPartChoice.start(
      numbers: noMap,
      road: StreetShape.none,
      part: StreetPart.whole,
    ).withSide(side);

    test('should keep each side between the bounds on both sides', () {
      expect(
        manual(Sides.both).withBounds(from: 2, to: 5).part,
        part(odd: range(3, 5), even: range(2, 4)),
      );
    });

    test('should bring the bounds onto the side shown', () {
      expect(
        manual(Sides.odd).withBounds(from: 2, to: 6).part,
        part(odd: range(3, 5), even: SidePart.all),
      );
    });

    test('should keep the bounds already on the side shown', () {
      expect(
        manual(Sides.even).withBounds(from: 2, to: 6).part,
        part(odd: SidePart.all, even: range(2, 6)),
      );
    });

    test('should hold the whole side when both bounds are blank', () {
      expect(
        manual(Sides.odd).withBounds(from: 3, to: 5).withBounds().part,
        StreetPart.whole,
      );
    });

    test('should start at the lowest number of the side when the first bound '
        'is blank', () {
      expect(
        manual(Sides.odd).withBounds(to: 5).part,
        part(odd: range(1, 5), even: SidePart.all),
      );
    });

    test('should end at the highest number of the side when the last bound '
        'is blank', () {
      expect(
        manual(Sides.odd).withBounds(from: 3).part,
        part(odd: range(3, 7), even: SidePart.all),
      );
    });

    test('should keep nothing of the side when no number of it is between '
        'the bounds', () {
      expect(
        manual(Sides.even).withBounds(from: 3, to: 3).part,
        part(odd: SidePart.all, even: SidePart.none),
      );
    });

    test('should stop a bound at the highest house number', () {
      expect(
        manual(Sides.odd).withBounds(from: 3, to: 123456).part,
        part(odd: range(3, HouseNumber.maxNumber), even: SidePart.all),
      );
    });

    test('should take the whole range of house numbers for a side without '
        'numbers', () {
      final choice = StreetPartChoice.start(
        numbers: [PartNumber(n('1'))],
        road: StreetShape.none,
        part: StreetPart.whole,
      );

      expect(
        choice.withSide(Sides.even).withBounds(to: 10).part,
        part(odd: SidePart.all, even: range(0, 10)),
      );
      expect(
        choice.withSide(Sides.even).withBounds(from: 4).part,
        part(odd: SidePart.all, even: range(4, HouseNumber.maxNumber - 1)),
      );
    });
  });

  group('bounds', () {
    test('should be blank for a side held whole or not at all', () {
      expect(_odd().bounds, (from: null, to: null));
      expect(
        _odd(
          part: part(odd: SidePart.none, even: SidePart.all),
        ).bounds,
        (from: null, to: null),
      );
    });

    test('should be the range of the side shown', () {
      final choice = _choice(
        part: part(odd: range(5, 9), even: range(2, 4)),
      );

      expect(choice.withSide(Sides.odd).bounds, (from: 5, to: 9));
      expect(choice.withSide(Sides.even).bounds, (from: 2, to: 4));
    });

    test('should span the ranges of both sides on « Les deux »', () {
      final choice = _choice(
        part: part(odd: range(5, 9), even: range(2, 4)),
      );

      expect(choice.bounds, (from: 2, to: 9));
    });
  });

  group('values', () {
    test('should compare part numbers by number and position', () {
      final one = PartNumber(n('1'), position: _oddDoor(0));

      expect(one, PartNumber(n('1'), position: _oddDoor(0)));
      expect(one.hashCode, PartNumber(n('1'), position: _oddDoor(0)).hashCode);
      expect(one, isNot(PartNumber(n('1'))));
      expect(one, isNot(PartNumber(n('3'), position: _oddDoor(0))));
      expect(one.toString(), contains('1'));
    });

    test('should compare dots by number, position and look', () {
      final dot = PartDot(
        number: n('1'),
        position: _oddDoor(0),
        look: PartDotLook.kept,
      );

      expect(
        dot.hashCode,
        PartDot(
          number: n('1'),
          position: _oddDoor(0),
          look: PartDotLook.kept,
        ).hashCode,
      );
      expect(
        dot,
        isNot(
          PartDot(
            number: n('3'),
            position: _oddDoor(0),
            look: PartDotLook.kept,
          ),
        ),
      );
      expect(
        dot,
        isNot(
          PartDot(
            number: n('1'),
            position: _oddDoor(1),
            look: PartDotLook.kept,
          ),
        ),
      );
      expect(
        dot,
        isNot(
          PartDot(
            number: n('1'),
            position: _oddDoor(0),
            look: PartDotLook.leftOut,
          ),
        ),
      );
      expect(dot.toString(), 'PartDot(1, kept)');
    });

    test('should compare the places of the marks by their numbers', () {
      expect(const MarkBefore(1).hashCode, const MarkBefore(1).hashCode);
      expect(const MarkBefore(1), isNot(const MarkBefore(3)));
      expect(const MarkBefore(1), isNot(const MarkAfter(1)));
      expect(const MarkAfter(1).hashCode, const MarkAfter(1).hashCode);
      expect(const MarkAfter(1), isNot(const MarkAfter(3)));
      expect(
        const MarkBetween(1, 3).hashCode,
        const MarkBetween(1, 3).hashCode,
      );
      expect(const MarkBetween(1, 3), isNot(const MarkBetween(1, 5)));
      expect(const MarkBetween(1, 3), isNot(const MarkBetween(3, 3)));
      expect(
        [
          const MarkBefore(1),
          const MarkBetween(1, 3),
          const MarkAfter(3),
        ].map((place) => place.toString()),
        ['MarkBefore(1)', 'MarkBetween(1, 3)', 'MarkAfter(3)'],
      );
    });
  });

  group('other secteurs', () {
    final centre = valueOf(RescueCentre.create('CS Villefranche'));
    SectorPart other(int sector, StreetPart held) => SectorPart(
      sector: valueOf(SectorNumber.create(sector)),
      centre: centre,
      part: held,
    );
    final twelve = other(12, part(odd: range(7, 13), even: SidePart.none));

    test('should know no other secteur until told', () {
      final choice = _choice();

      expect(choice.others, isEmpty);
      expect(choice.overlaps, isEmpty);
      expect(choice.drawing!.others, isEmpty);
    });

    test('should name the numbers both this part and another secteur hold, '
        'in street order, those without a position included', () {
      final choice = _choice().withOthers([twelve]);

      expect(choice.others, [twelve]);
      expect(choice.overlaps, [
        PartOverlap(other: twelve, numbers: [n('7'), n('9'), n('11'), n('13')]),
      ]);
    });

    test('should leave out the numbers this part does not hold', () {
      final choice = _choice(
        part: part(odd: range(1, 7), even: SidePart.all),
      ).withOthers([twelve]);

      expect(choice.overlaps.single.numbers, [n('7')]);
    });

    test('should leave out a secteur holding none of the part\'s numbers', () {
      final choice = _choice(
        part: part(odd: range(1, 5), even: SidePart.all),
      ).withOthers([twelve]);

      expect(choice.overlaps, isEmpty);
    });

    test('should follow the part as it changes', () {
      final choice = _choice().withOthers([twelve]).holdingNothing();

      expect(choice.others, [twelve]);
      expect(choice.overlaps, isEmpty);
    });

    test('should keep the others through a side shown, a mark moved and '
        'bounds typed', () {
      final choice = _choice()
          .withOthers([twelve])
          .withSide(Sides.odd)
          .withMark(PartMark.first, 1)
          .withBounds(from: 1, to: 9);

      expect(choice.others, [twelve]);
    });

    test('should keep the part, the side and the marks when told the '
        'others', () {
      final before = _odd(
        part: part(odd: range(3, 7), even: SidePart.all),
      );
      final choice = before.withOthers([twelve]);

      expect(choice.part, before.part);
      expect(choice.side, Sides.odd);
      expect(choice.first, before.first);
      expect(choice.last, before.last);
    });

    test('should give one overlap per secteur sharing numbers, in the '
        'order told', () {
      final eight = other(8, part(odd: SidePart.none, even: range(2, 2)));
      final choice = _choice().withOthers([twelve, eight]);

      expect(choice.overlaps.map((overlap) => overlap.other.sector.value), [
        12,
        8,
      ]);
      expect(choice.overlaps.last.numbers, [n('2')]);
    });

    test('should draw amber the dots kept that another secteur holds too, '
        'and only those', () {
      final drawing = _choice(
        part: part(odd: range(1, 9), even: SidePart.all),
      ).withOthers([twelve]).drawing!;

      expect(
        _labels(drawing.dots.where((dot) => dot.look == PartDotLook.shared)),
        ['7', '9'],
      );
      // 11 is the other secteur's, not this part's: left out.
      expect(drawing.dots[11].look, PartDotLook.leftOut);
      // 5 is only this part's.
      expect(drawing.dots[5].look, PartDotLook.kept);
    });

    test('should keep greyed the other side\'s dots another secteur holds', () {
      final both = other(12, StreetPart.whole);
      final drawing = _odd().withOthers([both]).drawing!;

      expect(drawing.dots[1].look, PartDotLook.otherSide);
      expect(drawing.dots[0].look, PartDotLook.shared);
    });

    test('should draw another secteur\'s stretch of the odd side from its '
        'first dot to its last, a little beyond, on the left of a road '
        'running east', () {
      final drawing = _choice().withOthers([twelve]).drawing!;
      final stretch = drawing.others.single;

      expect(stretch.sector, valueOf(SectorNumber.create(12)));
      expect(stretch.onLeft, isTrue);
      // 7 to 11 on the road, 3 m beyond each: 13 has no dot.
      expect(stretch.line.first.latitude, closeTo(45.98, 1e-9));
      expect(
        metresBetween(stretch.line.first, at(45.98, _lon(3))),
        closeTo(3, 0.01),
      );
      expect(stretch.line.first.longitude, lessThan(_lon(3)));
      expect(
        metresBetween(stretch.line.last, at(45.98, _lon(5))),
        closeTo(3, 0.01),
      );
      expect(stretch.line.last.longitude, greaterThan(_lon(5)));
      expect(stretch.labelAt.latitude, closeTo(45.98, 1e-9));
      expect(stretch.labelAt.longitude, closeTo(_lon(4), 1e-9));
    });

    test('should draw an even stretch on the right of a road running east', () {
      final even = other(8, part(odd: SidePart.none, even: range(4, 6)));
      final stretch = _choice().withOthers([even]).drawing!.others.single;

      expect(stretch.onLeft, isFalse);
      expect(stretch.sector, valueOf(SectorNumber.create(8)));
    });

    test('should draw a stretch per side held, the odd one first, for each '
        'secteur in turn', () {
      final eight = other(8, StreetPart.whole);
      final drawing = _choice().withOthers([twelve, eight]).drawing!;

      expect(
        [
          for (final stretch in drawing.others)
            (stretch.sector.value, stretch.onLeft),
        ],
        [(12, true), (8, true), (8, false)],
      );
    });

    test('should draw a single dot\'s stretch around it', () {
      final one = other(8, part(odd: range(5, 5), even: SidePart.none));
      final stretch = _choice().withOthers([one]).drawing!.others.single;

      expect(
        metresBetween(stretch.line.first, stretch.line.last),
        closeTo(6, 0.01),
      );
    });

    test('should draw no stretch for numbers without a dot', () {
      final thirteen = other(8, part(odd: range(13, 13), even: SidePart.none));

      expect(_choice().withOthers([thirteen]).drawing!.others, isEmpty);
    });

    test('should put a stretch on the side most of its houses stand', () {
      // 1 and 3 north of the road, 5 south: two of three on the left.
      final numbers = [
        PartNumber(n('1'), position: _oddDoor(0)),
        PartNumber(n('3'), position: _oddDoor(1)),
        PartNumber(n('5'), position: _evenDoor(2)),
      ];
      final odd = other(8, part(odd: SidePart.all, even: SidePart.none));
      final mostlyLeft = _choice(numbers: numbers).withOthers([odd]);
      final mostlyRight = _choice(
        numbers: [
          PartNumber(n('1'), position: _evenDoor(0)),
          PartNumber(n('3'), position: _evenDoor(1)),
          PartNumber(n('5'), position: _oddDoor(2)),
        ],
      ).withOthers([odd]);

      expect(mostlyLeft.drawing!.others.single.onLeft, isTrue);
      expect(mostlyRight.drawing!.others.single.onLeft, isFalse);
    });

    test('should put a stretch on the left when its houses are as many on '
        'each side', () {
      final odd = other(8, part(odd: SidePart.all, even: SidePart.none));
      final choice = _choice(
        numbers: [
          PartNumber(n('1'), position: _oddDoor(0)),
          PartNumber(n('3'), position: _evenDoor(1)),
        ],
      ).withOthers([odd]);

      expect(choice.drawing!.others.single.onLeft, isTrue);
    });

    test('should compare overlaps and secteur parts by value', () {
      final same = other(12, part(odd: range(7, 13), even: SidePart.none));
      final overlap = PartOverlap(other: twelve, numbers: [n('7')]);

      expect(same, twelve);
      expect(same.hashCode, twelve.hashCode);
      expect(twelve, isNot(other(13, twelve.part)));
      expect(twelve, isNot(other(12, StreetPart.whole)));
      expect(
        twelve,
        isNot(
          SectorPart(
            sector: twelve.sector,
            centre: valueOf(RescueCentre.create('CS Arnas')),
            part: twelve.part,
          ),
        ),
      );
      expect(twelve.toString(), 'SectorPart(12, CS Villefranche, 7–13, none)');
      expect(overlap, PartOverlap(other: same, numbers: [n('7')]));
      expect(
        overlap.hashCode,
        PartOverlap(other: same, numbers: [n('7')]).hashCode,
      );
      expect(overlap, isNot(PartOverlap(other: twelve, numbers: [n('9')])));
      expect(
        overlap,
        isNot(PartOverlap(other: other(8, twelve.part), numbers: [n('7')])),
      );
      expect(
        PartOverlap(other: twelve, numbers: [n('7'), n('9')]).toString(),
        'PartOverlap(12, 7, 9)',
      );
    });

    test('should compare the stretches by value', () {
      final stretch = _choice().withOthers([twelve]).drawing!.others.single;
      final again = _choice().withOthers([twelve]).drawing!.others.single;
      OtherStretch changed({
        int? sector,
        List<GeoPoint>? line,
        bool? onLeft,
        GeoPoint? labelAt,
      }) => OtherStretch(
        sector: sector == null
            ? stretch.sector
            : valueOf(SectorNumber.create(sector)),
        line: line ?? stretch.line,
        onLeft: onLeft ?? stretch.onLeft,
        labelAt: labelAt ?? stretch.labelAt,
      );

      expect(again, stretch);
      expect(again.hashCode, stretch.hashCode);
      expect(changed(sector: 8), isNot(stretch));
      expect(changed(line: stretch.line.reversed.toList()), isNot(stretch));
      expect(changed(onLeft: false), isNot(stretch));
      expect(changed(labelAt: _oddDoor(0)), isNot(stretch));
      expect(stretch.toString(), 'OtherStretch(12, 2 points, left)');
      expect(
        changed(onLeft: false).toString(),
        'OtherStretch(12, 2 points, right)',
      );
    });
  });
}
