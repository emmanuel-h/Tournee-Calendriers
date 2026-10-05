import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
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

  test('should save the hint typed in the sheet', () async {
    final change = valueOf(
      await setHouseDetails(lilasId, n('5'), ComeBackMark(comeBack('samedi'))),
    );

    expect(
      change,
      ComeBackSet(
        streetId: lilasId,
        before: five,
        stamp: leaAtTwo,
        comeBack: comeBack('samedi'),
      ),
    );
    expect(houseOf(streets[lilasId]!, '5').comeBack, comeBack('samedi'));
  });

  test('should remove the building\'s own come-back when unticked', () async {
    valueOf(
      await setHouseDetails(lilasId, n('8'), ComeBackMark(comeBack('gardien'))),
    );

    final change = valueOf(
      await setHouseDetails(lilasId, n('8'), const ComeBackMark(null)),
    );

    expect((change as ComeBackSet).comeBack, isNull);
    expect(houseOf(streets[lilasId]!, '8').comeBack, isNull);
  });

  test('should refuse a hint on a house that is not « repasser »', () async {
    final failure = failureOf(
      await setHouseDetails(lilasId, n('7'), ComeBackMark(comeBack('samedi'))),
    );

    expect(failure, const CommandRefused(HouseChangeFailure.notComeBack));
    expect(streets.saved, isEmpty);
  });

  test('should save the note typed in the sheet', () async {
    final change = valueOf(
      await setHouseDetails(lilasId, n('5'), const NoteMark(Note.empty)),
    );

    expect(
      change,
      NoteSet(
        streetId: lilasId,
        before: five,
        stamp: leaAtTwo,
        note: Note.empty,
      ),
    );
    expect(houseOf(streets[lilasId]!, '5').note, Note.empty);
  });

  test('should set the building its own note', () async {
    valueOf(
      await setHouseDetails(lilasId, n('8'), NoteMark(note('digicode 1234'))),
    );

    expect(houseOf(streets[lilasId]!, '8').note, note('digicode 1234'));
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
  });

  test('should fail when the street is unknown', () async {
    final failure = failureOf(
      await setHouseDetails(
        StreetId('rue-inconnue'),
        n('5'),
        const NoteMark(Note.empty),
      ),
    );

    expect(failure, const StreetNotFound<HouseChangeFailure>());
  });
}
