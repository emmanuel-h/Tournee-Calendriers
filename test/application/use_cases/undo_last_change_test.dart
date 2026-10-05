import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/mark_dwelling.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/application/use_cases/undo_last_change.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late UndoLastChange undo;

  setUp(() {
    streets = repositoryWithLilas();
    undo = UndoLastChange(streets);
  });

  test('should put the exact previous house back after a tap', () async {
    final markHouse = MarkHouse(streets, clockAtTwo(), leaOnThePhone());
    final marked = valueOf(await markHouse(lilasId, n('5'), VisitStatus.done));

    final change = valueOf(await undo(marked));

    expect(houseOf(streets[lilasId]!, '5'), five);
    expect(
      change,
      HouseReverted(
        streetId: lilasId,
        replaced: House(
          number: n('5'),
          status: VisitStatus.done,
          lastChange: leaAtTwo,
          position: townHallDoor,
        ),
        house: five,
      ),
    );
    expect(streets.saved.last.$2, change);
    expect(streets.saved, hasLength(2));
  });

  test('should put the exact previous door back', () async {
    final markDwelling = MarkDwelling(streets, clockAtTwo(), leaOnThePhone());
    final marked = valueOf(
      await markDwelling(
        lilasId,
        n('8'),
        rdc('01'),
        const StatusMark(VisitStatus.nobodyHome),
      ),
    );

    final change = valueOf(await undo(marked));

    expect(houseOf(streets[lilasId]!, '8'), eight);
    expect(change, isA<DwellingReverted>());
  });

  test('should bring a removed number back with its marks', () async {
    final editStreet = EditStreetNumbers(
      streets,
      clockAtTwo(),
      leaOnThePhone(),
    );
    final removed = valueOf(await editStreet(lilasId, RemoveNumber(n('5'))));

    valueOf(await undo(removed));

    expect(houseOf(streets[lilasId]!, '5'), five);
    expect(streets[lilasId]!.removedHouses, isEmpty);
  });

  test('should fail and save nothing when the street refuses', () async {
    final (_, added) = valueOf(lilas.addNumbers([n('9')]));

    final failure = failureOf(await undo(added));

    expect(failure, const CommandRefused(UndoFailure.notUndoable));
    expect(streets.saved, isEmpty);
  });

  test('should fail when the street of the change is unknown', () async {
    final change = StreetRestored(streetId: StreetId('rue-inconnue'));

    final failure = failureOf(await undo(change));

    expect(failure, const StreetNotFound<UndoFailure>());
  });
}
