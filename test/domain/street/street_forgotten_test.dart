// A house visited during a validated tournée that nobody marked (PLAN
// §5.20, #168): one tap marks it ✓ with no tournée on, unless it is
// visited already.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/calendars.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

/// Door 01 of the RdC of the building at number 8.
final _door = DwellingKey(escA, 0, d('01'));

/// Number 3 with [three], number 8 a building whose door 01 has [door].
Street _street({
  VisitStatus three = VisitStatus.toDo,
  VisitStatus door = VisitStatus.toDo,
}) => valueOf(
  Street.create(
    id: _lilas,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(
        number: n('3'),
        status: three,
        tries: tries(2),
        lastChange: paulAtThree,
      ),
      House(
        number: n('8'),
        building: building(topFloor: 0, doors: 2).withDwelling(
          escA,
          0,
          Dwelling(label: d('01'), status: door, lastChange: paulAtThree),
        ),
      ),
    ],
  ),
);

void main() {
  group('a house', () {
    for (final status in [
      VisitStatus.toDo,
      VisitStatus.nobodyHome,
      VisitStatus.comeBack,
    ]) {
      test('should be marked done, with one calendar, when it is '
          '${status.name}', () {
        final before = _street(three: status);

        final (street, change) = valueOf(
          before.markForgotten(n('3'), by: lea, at: twoPm),
        );

        final house = street.houses.first;
        expect(house.status, VisitStatus.done);
        expect(house.calendars, Calendars.one);
        expect(house.lastChange, leaAtTwo);
        expect(
          change,
          HouseMarked(
            streetId: _lilas,
            before: before.houses.first,
            stamp: leaAtTwo,
            status: VisitStatus.done,
          ),
        );
      });
    }

    for (final status in [VisitStatus.done, VisitStatus.refused]) {
      test('should be refused when it is ${status.name} already', () {
        expect(
          failureOf(
            _street(three: status).markForgotten(n('3'), by: lea, at: twoPm),
          ),
          ForgottenMarkFailure.alreadyVisited,
        );
      });
    }

    test('should be refused when the street has no such number', () {
      expect(
        failureOf(_street().markForgotten(n('5'), by: lea, at: twoPm)),
        ForgottenMarkFailure.notFound,
      );
    });

    test('should be refused for a building named without a door', () {
      expect(
        failureOf(_street().markForgotten(n('8'), by: lea, at: twoPm)),
        ForgottenMarkFailure.notFound,
      );
    });
  });

  group('a door', () {
    test('should be marked done when it is not visited', () {
      final before = _street(door: VisitStatus.nobodyHome);

      final (street, change) = valueOf(
        before.markForgotten(n('8'), door: _door, by: lea, at: twoPm),
      );

      final door = street.houses.last.building!.dwellingAt(_door)!;
      expect(door.status, VisitStatus.done);
      expect(door.lastChange, leaAtTwo);
      expect(change, isA<DwellingMarked>());
      expect((change as DwellingMarked).status, VisitStatus.done);
      expect(change.number, n('8'));
      expect(street.houses.first, before.houses.first);
    });

    for (final status in [VisitStatus.done, VisitStatus.refused]) {
      test('should be refused when it is ${status.name} already', () {
        expect(
          failureOf(
            _street(door: status)
                .markForgotten(n('8'), door: _door, by: lea, at: twoPm),
          ),
          ForgottenMarkFailure.alreadyVisited,
        );
      });
    }

    test('should be refused when there is no such door, or no building', () {
      expect(
        failureOf(
          _street().markForgotten(
            n('8'),
            door: DwellingKey(escA, 0, d('09')),
            by: lea,
            at: twoPm,
          ),
        ),
        ForgottenMarkFailure.notFound,
      );
      expect(
        failureOf(
          _street().markForgotten(n('3'), door: _door, by: lea, at: twoPm),
        ),
        ForgottenMarkFailure.notFound,
      );
    });
  });
}
