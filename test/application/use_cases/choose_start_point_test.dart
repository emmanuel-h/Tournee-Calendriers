import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  /// Where a phone holding [mine] and the phone [streets] opens.
  Future<StartPoint> startOf(
    MyTournees mine, {
    FakeStreetRepository? streets,
  }) => ChooseStartPoint(
    FakeMyTourneesStore(mine),
    streets ?? FakeStreetRepository(),
  )();

  final tournee8 = summaryOf('t8', 8, status: MemberStatus.pending);

  test('should open « Bienvenue » when the phone holds nothing', () async {
    expect(await startOf(MyTournees.none), const StartOnWelcome());
  });

  test(
    'should open the streets when the phone holds streets of its own',
    () async {
      expect(
        await startOf(MyTournees.none, streets: FakeStreetRepository([lilas])),
        const StartOnStreets(),
      );
    },
  );

  test('should open the streets when the phone holds only streets in the '
      'Corbeille', () async {
    final (deleted, _) = lilas.delete(by: lea, at: twoPm);

    expect(
      await startOf(MyTournees.none, streets: FakeStreetRepository([deleted])),
      const StartOnStreets(),
    );
  });

  test('should open the streets when a tournée is open', () async {
    final mine = valueOf(
      MyTournees.none.remember(tournee7).remember(tournee49).open(tournee49.id),
    );

    expect(await startOf(mine), const StartOnStreets());
  });

  test('should open the latest request waiting when the phone holds no '
      'street and no tournée is open', () async {
    final mine = MyTournees.none
        .remember(tournee7)
        .remember(tournee12)
        .remember(tournee8);

    expect(await startOf(mine), StartOnRequest(tournee8));
  });

  test('should open the streets rather than a request when the phone holds '
      'streets of its own', () async {
    expect(
      await startOf(
        MyTournees.none.remember(tournee7),
        streets: FakeStreetRepository([lilas]),
      ),
      const StartOnStreets(),
    );
  });

  test('should open the streets when the phone knows tournées but none is '
      'open and no request waits', () async {
    expect(
      await startOf(MyTournees.none.remember(tournee12)),
      const StartOnStreets(),
    );
  });

  test('should tell requests apart by their tournée', () {
    expect(StartOnRequest(tournee7), StartOnRequest(tournee7));
    expect(StartOnRequest(tournee7), isNot(StartOnRequest(tournee8)));
    expect(
      StartOnRequest(tournee7).hashCode,
      StartOnRequest(tournee7).hashCode,
    );
    expect(StartOnRequest(tournee7).toString(), 'StartOnRequest(t7)');
  });

  test('should fail when the phone storage cannot be read', () async {
    final broken = FakeStreetRepository()..watchError = StateError('disk');

    await expectLater(
      startOf(MyTournees.none, streets: broken),
      throwsA(isA<StateError>()),
    );
  });
}
