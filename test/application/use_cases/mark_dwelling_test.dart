import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/mark_dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
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
  late MarkDwelling markDwelling;

  setUp(() {
    streets = repositoryWithLilas();
    markDwelling = MarkDwelling(streets, clockAtTwo(), leaOnThePhone());
  });

  Dwelling? doorOf(String label) =>
      houseOf(streets[lilasId]!, '8').building!.dwellingAt(rdc(label));

  test('should save the status of the tapped door', () async {
    final change = valueOf(
      await markDwelling(
        lilasId,
        n('8'),
        rdc('02'),
        const StatusMark(VisitStatus.done),
      ),
    );

    expect(
      change,
      DwellingMarked(
        streetId: lilasId,
        number: n('8'),
        staircase: escA,
        level: 0,
        before: Dwelling(label: d('02')),
        stamp: leaAtTwo,
        status: VisitStatus.done,
      ),
    );
    expect(streets.saved.single.$2, change);
    expect(doorOf('02')!.status, VisitStatus.done);
    expect(doorOf('02')!.lastChange, leaAtTwo);
  });

  test('should save the hint of a door « repasser »', () async {
    valueOf(
      await markDwelling(
        lilasId,
        n('8'),
        rdc('02'),
        const StatusMark(VisitStatus.comeBack),
      ),
    );

    final change = valueOf(
      await markDwelling(
        lilasId,
        n('8'),
        rdc('02'),
        ComeBackMark(comeBack('soir')),
      ),
    );

    expect(change, isA<DwellingComeBackSet>());
    expect((change as DwellingComeBackSet).comeBack, comeBack('soir'));
    expect(doorOf('02')!.comeBack, comeBack('soir'));
  });

  test('should save the note of the door', () async {
    final change = valueOf(
      await markDwelling(lilasId, n('8'), rdc('01'), NoteMark(note('chat'))),
    );

    expect(change, isA<DwellingNoteSet>());
    expect((change as DwellingNoteSet).note, note('chat'));
    expect(doorOf('01')!.note, note('chat'));
  });

  test('should fail when the door is done and a hint is given', () async {
    final failure = failureOf(
      await markDwelling(
        lilasId,
        n('8'),
        rdc('01'),
        ComeBackMark(comeBack('soir')),
      ),
    );

    expect(failure, const CommandRefused(DwellingChangeFailure.notComeBack));
    expect(streets.saved, isEmpty);
  });

  test('should fail when the street is unknown', () async {
    final failure = failureOf(
      await markDwelling(
        StreetId('rue-inconnue'),
        n('8'),
        rdc('01'),
        const StatusMark(VisitStatus.done),
      ),
    );

    expect(failure, const StreetNotFound<DwellingChangeFailure>());
  });
}
