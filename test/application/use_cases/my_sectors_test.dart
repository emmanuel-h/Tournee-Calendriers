import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MySectors _manusPhone() => valueOf(
  MySectors.none
      .remember(sector49)
      .remember(sector12)
      .remember(sector7)
      .open(sector49.id),
);

void main() {
  late FakeMySectorsStore store;

  setUp(() => store = FakeMySectorsStore(_manusPhone()));

  group('ReadMySectors', () {
    test('should give the tournées the phone keeps', () {
      expect(ReadMySectors(store)(), _manusPhone());
    });
  });

  group('ObserveMySectors', () {
    test('should give each list saved', () async {
      final seen = <MySectors>[];
      ObserveMySectors(store)().listen(seen.add);

      await store.save(MySectors.none);

      expect(seen, [MySectors.none]);
    });
  });

  group('OpenSector', () {
    test('should open the tournée and keep it for the next launch', () async {
      final opened = await OpenSector(store)(sector12.id);

      expect(valueOf(opened), sector12);
      expect(store.saves.single.current, sector12);
      expect(store.saves.single.sectors, [sector49, sector12, sector7]);
    });

    test('should save nothing when the tournée is already open', () async {
      final opened = await OpenSector(store)(sector49.id);

      expect(valueOf(opened), sector49);
      expect(store.saves, isEmpty);
    });

    test(
      'should refuse and save nothing when the request is pending',
      () async {
        final opened = await OpenSector(store)(sector7.id);

        expect(failureOf(opened), OpenSectorFailure.requestPending);
        expect(store.saves, isEmpty);
      },
    );

    test(
      'should refuse and save nothing when the tournée is unknown',
      () async {
        final opened = await OpenSector(store)(SectorId('t99'));

        expect(failureOf(opened), OpenSectorFailure.unknownSector);
        expect(store.saves, isEmpty);
      },
    );
  });

  group('WatchJoinRequest', () {
    test('should follow the request the signed-in member sent', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchJoinRequest(
        directory,
        FakeMemberAccount(signedInMember: manuId),
      );

      final first = watch(sector7.id).first;
      directory.answer(sector7.id, MemberStatus.active);

      expect(await first, MemberStatus.active);
      expect(directory.watched, [(sector7.id, manuId)]);
    });

    test('should follow nothing when the phone never signed in', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchJoinRequest(directory, FakeMemberAccount());

      expect(await watch(sector7.id).isEmpty, isTrue);
      expect(directory.watched, isEmpty);
    });
  });

  group('SettleJoinRequest', () {
    test(
      'should make the tournée a member one when accepted, closed',
      () async {
        await SettleJoinRequest(store)(sector7.id, MemberStatus.active);

        expect(store.saves.single.sectors, [
          sector49,
          sector12,
          sector7.accepted(),
        ]);
        expect(store.saves.single.current, sector49);
      },
    );

    test('should forget the tournée when the request is gone', () async {
      await SettleJoinRequest(store)(sector7.id, null);

      expect(store.saves.single.sectors, [sector49, sector12]);
      expect(store.saves.single.current, sector49);
    });

    test('should save nothing while the request is pending', () async {
      await SettleJoinRequest(store)(sector7.id, MemberStatus.pending);

      expect(store.saves, isEmpty);
    });

    test(
      'should save nothing when the tournée is no longer a request',
      () async {
        await SettleJoinRequest(store)(sector12.id, null);
        await SettleJoinRequest(store)(sector12.id, MemberStatus.active);
        await SettleJoinRequest(store)(SectorId('t99'), null);

        expect(store.saves, isEmpty);
      },
    );
  });

  group('WatchMembership', () {
    test('should follow the membership of the signed-in member', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchMembership(
        directory,
        FakeMemberAccount(signedInMember: manuId),
      );

      final first = watch(sector12).first;
      directory.lose(sector12.id, SectorLoss.removed);

      expect(await first, SectorLoss.removed);
      expect(directory.memberships, [(sector12, manuId)]);
    });

    test('should follow nothing when the phone never signed in', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchMembership(directory, FakeMemberAccount());

      expect(await watch(sector12).isEmpty, isTrue);
      expect(directory.memberships, isEmpty);
    });
  });

  group('WatchOwnName', () {
    test('should follow the name the server holds for the signed-in '
        'member', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchOwnName(
        directory,
        FakeMemberAccount(signedInMember: manuId),
      );

      final heard = watch(sector12.id).take(2).toList();
      directory
        ..hearName(sector12.id, nameOf('Manu'))
        ..hearName(sector12.id, nameOf('Emmanuel'));

      expect(await heard, [nameOf('Manu'), nameOf('Emmanuel')]);
      expect(directory.ownNames, [(sector12.id, manuId)]);
    });

    test('should tell a name heard again only once, so a rename the server '
        'refused is not sent over and over', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchOwnName(
        directory,
        FakeMemberAccount(signedInMember: manuId),
      );

      final heard = watch(sector12.id).take(2).toList();
      directory
        ..hearName(sector12.id, nameOf('Manu'))
        ..hearName(sector12.id, nameOf('Manu'))
        ..hearName(sector12.id, nameOf('Emmanuel'));

      expect(await heard, [nameOf('Manu'), nameOf('Emmanuel')]);
    });

    test('should follow nothing when the phone never signed in', () async {
      final directory = FakeSectorDirectory();
      final watch = WatchOwnName(directory, FakeMemberAccount());

      expect(await watch(sector12.id).isEmpty, isTrue);
      expect(directory.ownNames, isEmpty);
    });
  });

  group('ForgetLostSector', () {
    test('should forget the open tournée lost, none open any more, and say '
        'which it was', () async {
      final lost = await ForgetLostSector(store)(
        sector49.id,
        SectorLoss.deleted,
      );

      expect(
        lost,
        LostSector(sector: sector49, loss: SectorLoss.deleted, wasOpen: true),
      );
      expect(store.saves.single.sectors, [sector12, sector7]);
      expect(store.saves.single.current, isNull);
    });

    test('should forget another tournée lost and keep the open one', () async {
      final lost = await ForgetLostSector(store)(
        sector12.id,
        SectorLoss.removed,
      );

      expect(
        lost,
        LostSector(sector: sector12, loss: SectorLoss.removed, wasOpen: false),
      );
      expect(store.saves.single.sectors, [sector49, sector7]);
      expect(store.saves.single.current, sector49);
    });

    test('should forget nothing and tell nothing when the tournée is gone '
        'already (left, deleted from this phone)', () async {
      final lost = await ForgetLostSector(store)(
        SectorId('t99'),
        SectorLoss.removed,
      );

      expect(lost, isNull);
      expect(store.saves, isEmpty);
    });

    test('should leave a pending request to its own answer', () async {
      final lost = await ForgetLostSector(store)(
        sector7.id,
        SectorLoss.removed,
      );

      expect(lost, isNull);
      expect(store.saves, isEmpty);
    });
  });

  group('LostSector', () {
    LostSector lostOf({
      SectorSummary? sector,
      SectorLoss loss = SectorLoss.removed,
      bool wasOpen = true,
    }) => LostSector(sector: sector ?? sector49, loss: loss, wasOpen: wasOpen);

    test('should equal another with the same tournée, loss and place', () {
      expect(lostOf(), lostOf());
      expect(lostOf().hashCode, lostOf().hashCode);
    });

    test('should differ by any field', () {
      expect(lostOf(), isNot(lostOf(sector: sector12)));
      expect(lostOf(), isNot(lostOf(loss: SectorLoss.deleted)));
      expect(lostOf(), isNot(lostOf(wasOpen: false)));
    });

    test('should name what was lost', () {
      expect('${lostOf()}', 'LostSector(t49, removed, open)');
      expect('${lostOf(wasOpen: false)}', 'LostSector(t49, removed, closed)');
    });
  });
}
