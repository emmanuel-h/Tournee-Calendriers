import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/move_streets_into_tournee.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../domain/tournee/tournee_fixtures.dart' as team_fixtures;
import '../../support/fakes/fake_moved_streets_log.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// « Les ajouter à la tournée » (PLAN §5.0): the streets of the phone
// storage (M1) go into the open tournée, once per tournée.
void main() {
  final t49 = team_fixtures.tourneeId;
  final t12 = TourneeId('t12');
  // Léa of the tournée's team, signed in on the phone.
  final leaUid = team_fixtures.leaId;
  // The id the phone made for itself in M1, which stamped its marks.
  final phoneId = MemberId('phone42');

  /// A street of the phone imported from the BAN street [banId], with
  /// number 4 marked done by the phone at two o'clock.
  Street phoneStreet(String id, String name, {String? banId}) => valueOf(
    Street.create(
      id: StreetId(id),
      name: name,
      commune: villefranche,
      banId: banId == null ? null : BanStreetId(banId),
      houses: [
        House(
          number: valueOf(HouseNumber.create(4)),
          status: VisitStatus.done,
          lastChange: ChangeStamp(by: phoneId, at: twoPm),
        ),
        House(number: valueOf(HouseNumber.create(6))),
      ],
    ),
  );

  final nationale = phoneStreet('s1', 'Rue Nationale', banId: '69264_0420');
  final morin = phoneStreet('s2', 'Rue Pierre Morin', banId: '69264_1460');
  // Typed in by hand: no BAN id.
  final impasse = phoneStreet('s3', 'Impasse des Lilas');
  final deleted = phoneStreet(
    's4',
    'Rue Paul Bert',
    banId: '69264_0682',
  ).delete(by: phoneId, at: twoPm).$1;

  group('CountStreetsToMove', () {
    late FakeStreetRepository phone;
    late FakeMovedStreetsLog log;
    late FakeTourneeRepository tournees;

    setUp(() {
      phone = FakeStreetRepository([nationale, morin, impasse, deleted]);
      log = FakeMovedStreetsLog();
      tournees = FakeTourneeRepository([team_fixtures.team()]);
    });

    CountStreetsToMove countAs(MemberId member) =>
        CountStreetsToMove(phone, log, tournees, FakeIdentity(member));

    test('should count the phone streets not in the Corbeille', () async {
      expect(await countAs(leaUid)(t49), 3);
    });

    test('should count none once they went into that tournée', () async {
      log = FakeMovedStreetsLog([t49]);

      expect(await countAs(leaUid)(t49), 0);
    });

    test('should count them for a tournée they did not go into', () async {
      log = FakeMovedStreetsLog([t12]);

      expect(await countAs(leaUid)(t49), 3);
    });

    test('should count none when the member is still pending', () async {
      expect(await countAs(team_fixtures.julieId)(t49), 0);
    });

    test('should count none when the member is not in the team', () async {
      expect(await countAs(phoneId)(t49), 0);
    });

    test('should count none when the tournée cannot be read', () async {
      tournees = FakeTourneeRepository();

      expect(await countAs(leaUid)(t49), 0);
    });

    test('should fail as the phone storage fails', () async {
      phone.watchError = StateError('unreadable');

      await expectLater(countAs(leaUid)(t49), throwsStateError);
    });

    test('should count none when the phone holds no street', () async {
      phone = FakeStreetRepository([deleted]);

      expect(await countAs(leaUid)(t49), 0);
    });
  });

  group('MoveStreetsIntoTournee', () {
    late FakeStreetRepository phone;
    late FakeStreetRepository tournee;
    late FakeMovedStreetsLog log;

    setUp(() {
      phone = FakeStreetRepository([nationale, morin, impasse, deleted]);
      tournee = FakeStreetRepository();
      log = FakeMovedStreetsLog();
    });

    MoveStreetsIntoTournee move() =>
        MoveStreetsIntoTournee(phone, tournee, FakeIdentity(leaUid), log);

    test('should add each phone street to the tournée', () async {
      final report = await move()(t49);

      expect(report.moved, 3);
      expect(report.alreadyThere, 0);
      expect(
        [for (final street in tournee.added) street.id],
        [StreetId('s1'), StreetId('s2'), StreetId('s3')],
      );
    });

    test('should leave the streets of the Corbeille on the phone', () async {
      await move()(t49);

      expect(tournee[StreetId('s4')], isNull);
    });

    test('should stamp the marks with the member, at their time', () async {
      await move()(t49);

      final moved = tournee[StreetId('s1')]!;
      expect(moved.houses.first.lastChange, ChangeStamp(by: leaUid, at: twoPm));
      expect(moved.houses.first.status, VisitStatus.done);
      expect(moved.name, nationale.name);
      expect(moved.banId, nationale.banId);
      expect(moved.commune, villefranche);
      expect(moved.houses.last, nationale.houses.last);
    });

    test('should keep the phone copies as they were', () async {
      await move()(t49);

      expect(phone[StreetId('s1')], same(nationale));
      expect(phone.saved, isEmpty);
    });

    test('should skip a street whose BAN street is in the tournée', () async {
      final teammates = phoneStreet(
        't-1',
        'Rue Nationale',
        banId: '69264_0420',
      );
      tournee = FakeStreetRepository([teammates]);

      final report = await move()(t49);

      expect(report.moved, 2);
      expect(report.alreadyThere, 1);
      expect(tournee[StreetId('s1')], isNull);
      expect(tournee[StreetId('t-1')], same(teammates));
    });

    test('should skip a street whose BAN street is in its Corbeille', () async {
      final binned = phoneStreet(
        't-1',
        'Rue Nationale',
        banId: '69264_0420',
      ).delete(by: leaUid, at: threePm).$1;
      tournee = FakeStreetRepository([binned]);

      final report = await move()(t49);

      expect(report.moved, 2);
      expect(report.alreadyThere, 1);
    });

    test('should skip a street the tournée holds under the same id', () async {
      tournee = FakeStreetRepository([impasse.restampedBy(leaUid)]);

      final report = await move()(t49);

      expect(report.moved, 2);
      expect(report.alreadyThere, 1);
      expect(
        [for (final street in tournee.added) street.id],
        [StreetId('s1'), StreetId('s2')],
      );
    });

    test('should move nothing and remember nothing when the phone storage '
        'fails', () async {
      phone.watchError = StateError('unreadable');

      await expectLater(move()(t49), throwsStateError);
      expect(tournee.added, isEmpty);
      expect(log.remembered, isEmpty);
    });

    test('should remember the tournée the streets went into', () async {
      await move()(t49);

      expect(log.remembered, [t49]);
    });

    test('should remember it when every street was already there', () async {
      tournee = FakeStreetRepository([
        nationale.restampedBy(leaUid),
        morin.restampedBy(leaUid),
        impasse.restampedBy(leaUid),
      ]);

      final report = await move()(t49);

      expect(report.moved, 0);
      expect(report.alreadyThere, 3);
      expect(log.remembered, [t49]);
    });

    test('should tell how far it went, street after street', () async {
      final steps = <(int, int)>[];

      await move()(t49, onProgress: (done, total) => steps.add((done, total)));

      expect(steps, [(0, 3), (1, 3), (2, 3), (3, 3)]);
    });

    test('should remember the tournée only after the last street', () async {
      final rememberedAt = <int>[];

      await move()(
        t49,
        onProgress: (done, total) => rememberedAt.add(log.remembered.length),
      );

      expect(rememberedAt, [0, 0, 0, 0]);
      expect(log.remembered, [t49]);
    });
  });

  group('StreetsMoved', () {
    test('should be equal when the counts are equal', () {
      const a = StreetsMoved(moved: 10, alreadyThere: 2);
      const b = StreetsMoved(moved: 10, alreadyThere: 2);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const StreetsMoved(moved: 9, alreadyThere: 2)));
      expect(a, isNot(const StreetsMoved(moved: 10, alreadyThere: 3)));
      expect(a, isNot(Object()));
    });

    test('should show its counts when printed', () {
      expect(
        const StreetsMoved(moved: 10, alreadyThere: 2).toString(),
        'StreetsMoved(10 moved, 2 already there)',
      );
    });
  });
}
