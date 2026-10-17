// « Me l'attribuer », « La faire aussi » and « Ne plus la faire » (PLAN §5.4,
// §5.5): the member on the phone takes a street of the tournée or stops
// covering it. Works offline, like every change of a street.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_assignment.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;

  setUp(() => streets = repositoryWithLilas());

  group('TakeStreet', () {
    test('should give the street to the member on the phone', () async {
      final change = valueOf(
        await TakeStreet(streets, leaOnThePhone())(lilasId),
      );

      expect(change, StreetTaken(streetId: lilasId, member: lea));
      expect(streets[lilasId]!.assignees, {lea});
      expect(streets.saved.single.$2, change);
    });

    test('should keep the members who cover it already', () async {
      final (paulsStreet, took) = valueOf(lilas.take(paul));
      await streets.save(paulsStreet, took);

      await TakeStreet(streets, leaOnThePhone())(lilasId);

      expect(streets[lilasId]!.assignees, {paul, lea});
    });

    test('should refuse when the member covers it already', () async {
      await TakeStreet(streets, leaOnThePhone())(lilasId);

      final failure = failureOf(
        await TakeStreet(streets, leaOnThePhone())(lilasId),
      );

      expect(
        failure,
        const CommandRefused<AssignmentFailure>(
          AssignmentFailure.alreadyAssigned,
        ),
      );
      expect(streets.saved, hasLength(1));
    });

    test('should say when the street is not there', () async {
      final failure = failureOf(
        await TakeStreet(streets, leaOnThePhone())(StreetId('gone')),
      );

      expect(failure, const StreetNotFound<AssignmentFailure>());
    });
  });

  group('ReleaseStreet', () {
    test('should take the member on the phone off the street', () async {
      await TakeStreet(streets, leaOnThePhone())(lilasId);

      final change = valueOf(
        await ReleaseStreet(streets, leaOnThePhone())(lilasId),
      );

      expect(change, StreetReleased(streetId: lilasId, member: lea));
      expect(streets[lilasId]!.assignees, isEmpty);
      expect(streets.saved.last.$2, change);
    });

    test('should leave the other members on the street', () async {
      final (paulsStreet, took) = valueOf(lilas.take(paul));
      await streets.save(paulsStreet, took);
      await TakeStreet(streets, leaOnThePhone())(lilasId);

      await ReleaseStreet(streets, leaOnThePhone())(lilasId);

      expect(streets[lilasId]!.assignees, {paul});
    });

    test('should refuse when the member does not cover it', () async {
      final failure = failureOf(
        await ReleaseStreet(streets, leaOnThePhone())(lilasId),
      );

      expect(
        failure,
        const CommandRefused<AssignmentFailure>(AssignmentFailure.notAssigned),
      );
      expect(streets.saved, isEmpty);
    });

    test('should say when the street is not there', () async {
      final failure = failureOf(
        await ReleaseStreet(streets, leaOnThePhone())(StreetId('gone')),
      );

      expect(failure, const StreetNotFound<AssignmentFailure>());
    });
  });
}
