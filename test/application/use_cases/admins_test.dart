import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/application/use_cases/admins.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/results.dart';

/// The 12 of the CS Villefranche as « Tous les secteurs » lists it.
SectorOverview overview12({bool callerIsActive = false}) => SectorOverview(
  id: SectorId('t12'),
  number: sector12.number,
  centre: csVillefranche,
  campaign: campaign2026,
  activeMembers: 3,
  pendingRequests: 1,
  callerIsActive: callerIsActive,
);

void main() {
  group('ObserveAdminStatus', () {
    test('should tell the phone\'s grants, then each change', () async {
      final admins = FakeAdminStatus();
      final seen = <AdminGrants>[];
      final listening = ObserveAdminStatus(admins)().listen(seen.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();

      admins.phoneGrants = grantsInVillefranche({Permission.teams});
      await pumpEventQueue();

      expect(seen, [
        AdminGrants.none,
        grantsInVillefranche({Permission.teams}),
      ]);
    });
  });

  group('grantsOf', () {
    test('should give the grants the phone knows', () async {
      final admins = FakeAdminStatus(
        phoneGrants: grantsInVillefranche({Permission.streets}),
      );

      expect(
        await grantsOf(admins),
        grantsInVillefranche({Permission.streets}),
      );
    });

    test('should give none when they cannot be read', () async {
      final admins = FakeAdminStatus(phoneIsAdmin: true)..unreadable = true;

      expect(await grantsOf(admins), AdminGrants.none);
    });
  });

  group('IsMemberAdmin', () {
    test('should say whether a member is an admin', () async {
      final admins = FakeAdminStatus(admins: [manuId]);

      expect(await IsMemberAdmin(admins)(manuId), isTrue);
      expect(await IsMemberAdmin(admins)(leaId), isFalse);
      expect(admins.asked, [manuId, leaId]);
    });
  });

  group('ListAllSectors', () {
    late FakeSectorDirectory directory;
    late FakeAdminStatus admins;
    final gleize = valueOf(RescueCentre.create('CS Gleizé'));
    final gleize7 = SectorOverview(
      id: SectorId('g7'),
      number: valueOf(SectorNumber.create(7)),
      centre: gleize,
      campaign: campaign2026,
      activeMembers: 1,
      pendingRequests: 0,
      callerIsActive: false,
    );

    setUp(() {
      directory = FakeSectorDirectory()..overviews = [overview12(), gleize7];
      admins = FakeAdminStatus(
        phoneGrants: grantsInVillefranche({Permission.teams}),
      );
    });

    test(
      'should list the secteurs of the CS the admin holds a permission in',
      () async {
        final account = FakeMemberAccount(signedInMember: samId);

        final all = valueOf(await ListAllSectors(directory, account, admins)());

        expect(all, [overview12()]);
        expect(directory.allAsked, [samId]);
        expect(directory.allCentresAsked, [
          {csVillefranche.key},
        ]);
      },
    );

    test('should ask for every CS of the admin', () async {
      admins.phoneGrants = AdminGrants(
        centres: {
          csVillefranche.key: {Permission.campaign},
          gleize.key: {Permission.streets},
        },
      );

      final all = valueOf(
        await ListAllSectors(
          directory,
          FakeMemberAccount(signedInMember: samId),
          admins,
        )(),
      );

      expect(all, [overview12(), gleize7]);
      expect(directory.allCentresAsked, [
        {csVillefranche.key, gleize.key},
      ]);
    });

    test('should refuse, asking nothing, when the phone holds no CS (a '
        'super admin\'s global permissions alone)', () async {
      admins.phoneGrants = AdminGrants(global: GlobalPermission.values.toSet());

      final failure = failureOf(
        await ListAllSectors(
          directory,
          FakeMemberAccount(signedInMember: samId),
          admins,
        )(),
      );

      expect(failure, DirectoryFailure.notAdmin);
      expect(directory.allAsked, isEmpty);
    });

    test('should sign in first when the phone has no account yet', () async {
      final account = FakeMemberAccount(nextMember: samId);

      valueOf(await ListAllSectors(directory, account, admins)());

      expect(account.signInCalls, 1);
      expect(directory.allAsked, [samId]);
    });

    test('should tell when the phone cannot sign in', () async {
      final account = FakeMemberAccount();

      final failure = failureOf(
        await ListAllSectors(directory, account, admins)(),
      );

      expect(failure, DirectoryFailure.noNetwork);
      expect(directory.allAsked, isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      directory.offline = true;

      final failure = failureOf(
        await ListAllSectors(
          directory,
          FakeMemberAccount(signedInMember: samId),
          admins,
        )(),
      );

      expect(failure, DirectoryFailure.noNetwork);
    });

    test('should tell when the server says the phone is no longer an '
        'admin\'s', () async {
      directory.notAdmin = true;

      final failure = failureOf(
        await ListAllSectors(
          directory,
          FakeMemberAccount(signedInMember: samId),
          admins,
        )(),
      );

      expect(failure, DirectoryFailure.notAdmin);
    });
  });

  group('OpenAsAdmin', () {
    late FakeMySectorsStore store;

    setUp(() {
      store = FakeMySectorsStore(
        valueOf(MySectors.none.remember(sector49).open(sector49.id)),
      );
    });

    test('should keep a secteur the admin is not in as visited, and open '
        'it', () async {
      final opened = await OpenAsAdmin(store)(overview12());

      final visited = summaryOf('t12', 12, status: MemberStatus.visiting);
      expect(opened, visited);
      expect(store.mySectors.sectors, [sector49, visited]);
      expect(store.mySectors.currentId, SectorId('t12'));
      expect(store.saves, hasLength(1));
    });

    test(
      'should keep a secteur the admin is in as theirs, and open it',
      () async {
        final opened = await OpenAsAdmin(store)(
          overview12(callerIsActive: true),
        );

        expect(opened, sector12);
        expect(store.mySectors.current, sector12);
      },
    );

    test('should replace what the phone kept of the secteur', () async {
      store.mySectors = MySectors.none.remember(
        summaryOf('t12', 12, status: MemberStatus.pending),
      );

      final opened = await OpenAsAdmin(store)(overview12());

      expect(store.mySectors.sectors, [opened]);
      expect(opened.status, MemberStatus.visiting);
    });

    test(
      'should take the number, centre and campaign the server gives',
      () async {
        final moved = SectorOverview(
          id: SectorId('t12'),
          number: sector12.number,
          centre: csVillefranche,
          campaign: campaign2027,
          activeMembers: 0,
          pendingRequests: 0,
          callerIsActive: false,
        );

        final opened = await OpenAsAdmin(store)(moved);

        expect(
          opened,
          SectorSummary(
            id: SectorId('t12'),
            number: sector12.number,
            centre: csVillefranche,
            campaign: campaign2027,
            status: MemberStatus.visiting,
          ),
        );
      },
    );
  });
}
