import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

House _house(VisitStatus status) => House(number: n('12'), status: status);

Dwelling _door(VisitStatus status) => Dwelling(label: d('51'), status: status);

HouseMarked _houseMarked(VisitStatus from, VisitStatus to) => HouseMarked(
  streetId: _lilas,
  before: _house(from),
  stamp: leaAtTwo,
  status: to,
);

DwellingMarked _doorMarked(VisitStatus from, VisitStatus to) => DwellingMarked(
  streetId: _lilas,
  number: n('8'),
  staircase: escA,
  level: 5,
  before: _door(from),
  stamp: leaAtTwo,
  status: to,
);

void main() {
  const visitedStatuses = [VisitStatus.done, VisitStatus.refused];
  const otherStatuses = [
    VisitStatus.toDo,
    VisitStatus.nobodyHome,
    VisitStatus.comeBack,
  ];

  group('a house marked', () {
    test('should count it when it becomes ✓ or ⊘', () {
      for (final from in otherStatuses) {
        for (final to in visitedStatuses) {
          expect(
            RoundVisit.of(_houseMarked(from, to)),
            RoundVisit.visited,
            reason: '$from → $to',
          );
        }
      }
    });

    test('should take it back when it is no longer ✓ or ⊘', () {
      for (final from in visitedStatuses) {
        for (final to in otherStatuses) {
          expect(
            RoundVisit.of(_houseMarked(from, to)),
            RoundVisit.unvisited,
            reason: '$from → $to',
          );
        }
      }
    });

    test('should leave the count when it stays visited or not', () {
      expect(
        RoundVisit.of(_houseMarked(VisitStatus.done, VisitStatus.refused)),
        RoundVisit.none,
      );
      expect(
        RoundVisit.of(_houseMarked(VisitStatus.refused, VisitStatus.done)),
        RoundVisit.none,
      );
      expect(
        RoundVisit.of(_houseMarked(VisitStatus.toDo, VisitStatus.nobodyHome)),
        RoundVisit.none,
      );
    });
  });

  test('should count a door like a house', () {
    expect(
      RoundVisit.of(_doorMarked(VisitStatus.toDo, VisitStatus.refused)),
      RoundVisit.visited,
    );
    expect(
      RoundVisit.of(_doorMarked(VisitStatus.done, VisitStatus.comeBack)),
      RoundVisit.unvisited,
    );
    expect(
      RoundVisit.of(_doorMarked(VisitStatus.toDo, VisitStatus.comeBack)),
      RoundVisit.none,
    );
  });

  test('should take back a ✓ turned into « de nouveau personne »', () {
    expect(
      RoundVisit.of(
        HouseNobodyHomeAgain(
          streetId: _lilas,
          before: _house(VisitStatus.done),
          stamp: leaAtTwo,
          tries: tries(2),
        ),
      ),
      RoundVisit.unvisited,
    );
    expect(
      RoundVisit.of(
        HouseNobodyHomeAgain(
          streetId: _lilas,
          before: _house(VisitStatus.nobodyHome),
          stamp: leaAtTwo,
          tries: tries(2),
        ),
      ),
      RoundVisit.none,
    );
    expect(
      RoundVisit.of(
        DwellingNobodyHomeAgain(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 5,
          before: _door(VisitStatus.refused),
          stamp: leaAtTwo,
          tries: tries(2),
        ),
      ),
      RoundVisit.unvisited,
    );
  });

  test('should follow the statuses an undo puts back', () {
    expect(
      RoundVisit.of(
        HouseReverted(
          streetId: _lilas,
          replaced: _house(VisitStatus.done),
          house: _house(VisitStatus.toDo),
          stamp: leaAtTwo,
        ),
      ),
      RoundVisit.unvisited,
    );
    expect(
      RoundVisit.of(
        DwellingReverted(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 5,
          replaced: _door(VisitStatus.toDo),
          dwelling: _door(VisitStatus.done),
          stamp: leaAtTwo,
        ),
      ),
      RoundVisit.visited,
    );
  });

  test('should leave the count on a change of no status', () {
    expect(
      RoundVisit.of(
        ComeBackSet(
          streetId: _lilas,
          before: _house(VisitStatus.comeBack),
          stamp: leaAtTwo,
          comeBack: comeBack('2026-10-24', hour: 18),
        ),
      ),
      RoundVisit.none,
    );
    expect(
      RoundVisit.of(StreetDeleted(streetId: _lilas, deletion: leaAtTwo)),
      RoundVisit.none,
    );
    expect(
      RoundVisit.of(
        StreetRenamed(
          streetId: _lilas,
          before: streetName('Rue des Lilas'),
          name: streetName('Rue des Tilleuls'),
        ),
      ),
      RoundVisit.none,
    );
  });

  test('should leave the count when a done house takes a calendar', () {
    expect(
      RoundVisit.of(
        HouseCalendarsCounted(
          streetId: _lilas,
          before: _house(VisitStatus.done),
          stamp: leaAtTwo,
          calendars: calendars(2),
        ),
      ),
      RoundVisit.none,
    );
    expect(
      RoundVisit.of(
        DwellingCalendarsCounted(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 5,
          before: _door(VisitStatus.done),
          stamp: leaAtTwo,
          calendars: calendars(2),
        ),
      ),
      RoundVisit.none,
    );
  });

  test('should turn a count around when the change is undone', () {
    expect(RoundVisit.visited.undone, RoundVisit.unvisited);
    expect(RoundVisit.unvisited.undone, RoundVisit.visited);
    expect(RoundVisit.none.undone, RoundVisit.none);
  });
}
