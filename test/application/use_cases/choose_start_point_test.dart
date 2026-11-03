import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  /// Where a phone holding [mine] and the phone [streets] opens.
  Future<StartPoint> startOf(MySectors mine, {FakeStreetRepository? streets}) =>
      ChooseStartPoint(
        FakeMySectorsStore(mine),
        streets ?? FakeStreetRepository(),
      )();

  final sector8 = summaryOf('t8', 8, status: MemberStatus.pending);

  test('should open « Bienvenue » when the phone holds nothing', () async {
    expect(await startOf(MySectors.none), const StartOnWelcome());
  });

  test(
    'should open the streets when the phone holds streets of its own',
    () async {
      expect(
        await startOf(MySectors.none, streets: FakeStreetRepository([lilas])),
        const StartOnStreets(),
      );
    },
  );

  test('should open the streets when the phone holds only streets in the '
      'Corbeille', () async {
    final (deleted, _) = lilas.delete(by: lea, at: twoPm);

    expect(
      await startOf(MySectors.none, streets: FakeStreetRepository([deleted])),
      const StartOnStreets(),
    );
  });

  test('should open the streets when a tournée is open', () async {
    final mine = valueOf(
      MySectors.none.remember(sector7).remember(sector49).open(sector49.id),
    );

    expect(await startOf(mine), const StartOnStreets());
  });

  test('should open the latest request waiting when the phone holds no '
      'street and no tournée is open', () async {
    final mine = MySectors.none
        .remember(sector7)
        .remember(sector12)
        .remember(sector8);

    expect(await startOf(mine), StartOnRequest(sector8));
  });

  test('should open the streets rather than a request when the phone holds '
      'streets of its own', () async {
    expect(
      await startOf(
        MySectors.none.remember(sector7),
        streets: FakeStreetRepository([lilas]),
      ),
      const StartOnStreets(),
    );
  });

  test('should open the streets when the phone knows tournées but none is '
      'open and no request waits', () async {
    expect(
      await startOf(MySectors.none.remember(sector12)),
      const StartOnStreets(),
    );
  });

  test('should tell requests apart by their tournée', () {
    expect(StartOnRequest(sector7), StartOnRequest(sector7));
    expect(StartOnRequest(sector7), isNot(StartOnRequest(sector8)));
    expect(StartOnRequest(sector7).hashCode, StartOnRequest(sector7).hashCode);
    expect(StartOnRequest(sector7).toString(), 'StartOnRequest(t7)');
  });

  test('should fail when the phone storage cannot be read', () async {
    final broken = FakeStreetRepository()..watchError = StateError('disk');

    await expectLater(
      startOf(MySectors.none, streets: broken),
      throwsA(isA<StateError>()),
    );
  });
}
