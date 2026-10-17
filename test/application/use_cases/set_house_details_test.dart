import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  late SetHouseDetails setHouseDetails;
  late FakeStreetRepository streets;

  setUp(() {
    streets = repositoryWithLilas();
    setHouseDetails = SetHouseDetails(streets, clockAtTwo(), leaOnThePhone());
  });

  test('should save the status chosen in the sheet', () async {
    final change = valueOf(
      await setHouseDetails(
        lilasId,
        n('5'),
        // Built at run time, as the screen does: a `const` instance is made
        // by the compiler, so its constructor line would never count as
        // covered.
        // ignore: prefer_const_constructors
        StatusMark(VisitStatus.toDo),
      ),
    );

    expect(
      change,
      HouseMarked(
        streetId: lilasId,
        before: five,
        stamp: leaAtTwo,
        status: VisitStatus.toDo,
      ),
    );
    expect(streets.saved.single.$2, change);
    expect(houseOf(streets[lilasId]!, '5').status, VisitStatus.toDo);
  });

  test('should stamp the change with the clock and the member', () async {
    final clock = clockAtTwo()..time = threePm;
    setHouseDetails = SetHouseDetails(streets, clock, leaOnThePhone());

    final change = valueOf(
      await setHouseDetails(
        lilasId,
        n('7'),
        const StatusMark(VisitStatus.nobodyHome),
      ),
    );

    expect(change.stamp.at, threePm);
    expect(change.stamp.by, lea);
  });

  test('should keep a second quick tap on another house', () async {
    // Two taps are two events: the second starts on a later turn of the
    // event loop (`Duration.zero`), even before the first one's save ends.
    final first = setHouseDetails(
      lilasId,
      n('5'),
      const StatusMark(VisitStatus.done),
    );
    await Future<void>.delayed(Duration.zero);
    final second = setHouseDetails(
      lilasId,
      n('7'),
      const StatusMark(VisitStatus.done),
    );
    await Future.wait([first, second]);

    expect(houseOf(streets[lilasId]!, '5').status, VisitStatus.done);
    expect(houseOf(streets[lilasId]!, '7').status, VisitStatus.done);
  });

  test('should save the hint typed in the sheet', () async {
    final change = valueOf(
      await setHouseDetails(
        lilasId,
        n('5'),
        ComeBackMark(comeBack('2026-11-07')),
      ),
    );

    expect(
      change,
      ComeBackSet(
        streetId: lilasId,
        before: five,
        stamp: leaAtTwo,
        comeBack: comeBack('2026-11-07'),
      ),
    );
    expect(houseOf(streets[lilasId]!, '5').comeBack, comeBack('2026-11-07'));
  });

  test('should remove the building\'s own come-back when unticked', () async {
    valueOf(
      await setHouseDetails(
        lilasId,
        n('8'),
        ComeBackMark(comeBack('2026-11-03', hour: 10)),
      ),
    );

    final change = valueOf(
      await setHouseDetails(lilasId, n('8'), const ComeBackMark(null)),
    );

    expect((change as ComeBackSet).comeBack, isNull);
    expect(houseOf(streets[lilasId]!, '8').comeBack, isNull);
  });

  test('should add a try when nobody is home again', () async {
    final change = valueOf(
      await setHouseDetails(
        lilasId,
        n('5'),
        // ignore: prefer_const_constructors
        NobodyHomeAgainMark(),
      ),
    );

    expect(
      change,
      HouseNobodyHomeAgain(
        streetId: lilasId,
        before: five,
        stamp: leaAtTwo,
        tries: tries(1),
      ),
    );
    expect(streets.saved.single.$2, change);
    expect(houseOf(streets[lilasId]!, '5').status, VisitStatus.nobodyHome);
  });

  test('should refuse nobody home again on a house to do', () async {
    final failure = failureOf(
      await setHouseDetails(lilasId, n('7'), const NobodyHomeAgainMark()),
    );

    expect(failure, const CommandRefused(HouseChangeFailure.notToVisitAgain));
    expect(streets.saved, isEmpty);
  });

  test('should refuse a hint on a house that is not « repasser »', () async {
    final failure = failureOf(
      await setHouseDetails(
        lilasId,
        n('7'),
        ComeBackMark(comeBack('2026-11-07')),
      ),
    );

    expect(failure, const CommandRefused(HouseChangeFailure.notComeBack));
    expect(streets.saved, isEmpty);
  });

  test('should fail when the street refuses the mark', () async {
    final failure = failureOf(
      await setHouseDetails(
        lilasId,
        n('8'),
        const StatusMark(VisitStatus.done),
      ),
    );

    expect(failure, const CommandRefused(HouseChangeFailure.houseIsBuilding));
    expect(streets.saved, isEmpty);
    expect(streets[lilasId], same(lilas));
  });

  test('should fail when the street is unknown', () async {
    final failure = failureOf(
      await setHouseDetails(
        StreetId('rue-inconnue'),
        n('5'),
        const StatusMark(VisitStatus.done),
      ),
    );

    expect(failure, const StreetNotFound<HouseChangeFailure>());
    expect(streets.saved, isEmpty);
  });
}
