import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  test('should save the marked house and return the change', () async {
    final streets = repositoryWithLilas();
    final markHouse = MarkHouse(streets, clockAtTwo(), leaOnThePhone());

    final change = valueOf(await markHouse(lilasId, n('7'), VisitStatus.done));

    expect(
      change,
      HouseMarked(
        streetId: lilasId,
        before: seven,
        stamp: leaAtTwo,
        status: VisitStatus.done,
      ),
    );
    final (saved, savedChange) = streets.saved.single;
    expect(savedChange, change);
    expect(houseOf(saved, '7').status, VisitStatus.done);
    expect(houseOf(saved, '7').lastChange, leaAtTwo);
    expect(houseOf(streets[lilasId]!, '7').status, VisitStatus.done);
  });

  test('should stamp the change with the clock and the member', () async {
    final streets = repositoryWithLilas();
    final clock = clockAtTwo()..time = threePm;
    final markHouse = MarkHouse(streets, clock, leaOnThePhone());

    final change = valueOf(
      await markHouse(lilasId, n('7'), VisitStatus.nobodyHome),
    );

    expect(change.stamp.at, threePm);
    expect(change.stamp.by, lea);
  });

  test('should keep a second quick tap on another house', () async {
    final streets = repositoryWithLilas();
    final markHouse = MarkHouse(streets, clockAtTwo(), leaOnThePhone());

    // Two taps are two events: the second starts on a later turn of the
    // event loop (`Duration.zero`), even before the first one's save ends.
    final first = markHouse(lilasId, n('5'), VisitStatus.done);
    await Future<void>.delayed(Duration.zero);
    final second = markHouse(lilasId, n('7'), VisitStatus.done);
    await Future.wait([first, second]);

    expect(houseOf(streets[lilasId]!, '5').status, VisitStatus.done);
    expect(houseOf(streets[lilasId]!, '7').status, VisitStatus.done);
  });

  test('should fail and save nothing when the street is unknown', () async {
    final streets = repositoryWithLilas();
    final markHouse = MarkHouse(streets, clockAtTwo(), leaOnThePhone());

    final failure = failureOf(
      await markHouse(StreetId('rue-inconnue'), n('7'), VisitStatus.done),
    );

    expect(failure, const StreetNotFound<HouseChangeFailure>());
    expect(streets.saved, isEmpty);
  });

  test('should fail and save nothing when the street refuses', () async {
    final streets = repositoryWithLilas();
    final markHouse = MarkHouse(streets, clockAtTwo(), leaOnThePhone());

    final failure = failureOf(
      await markHouse(lilasId, n('8'), VisitStatus.done),
    );

    expect(failure, const CommandRefused(HouseChangeFailure.houseIsBuilding));
    expect(streets.saved, isEmpty);
    expect(streets[lilasId], same(lilas));
  });
}
