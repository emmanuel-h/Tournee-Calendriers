import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/results.dart';

void main() {
  late FakeAdminStatus admins;
  late FakeMySectorsStore store;

  ProviderContainer phone() {
    final container = ProviderContainer(
      overrides: [
        adminStatusProvider.overrideWithValue(admins),
        mySectorsStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    container.listen(adminProvider, (_, _) {});
    return container;
  }

  setUp(() {
    admins = FakeAdminStatus();
    store = FakeMySectorsStore();
  });

  group('adminProvider', () {
    test('should hold no grant until they are known', () {
      admins = FakeAdminStatus(phoneIsAdmin: true);

      expect(phone().read(adminProvider), AdminGrants.none);
    });

    test('should hold the grants once known', () async {
      admins = FakeAdminStatus(
        phoneGrants: grantsInVillefranche({Permission.teams}),
      );
      final container = phone();
      await pumpEventQueue();

      expect(
        container.read(adminProvider),
        grantsInVillefranche({Permission.teams}),
      );
    });

    test('should follow the grants as they change', () async {
      final container = phone();
      await pumpEventQueue();

      admins.phoneGrants = grantsInVillefranche({Permission.streets});
      expect(
        container.read(adminProvider),
        grantsInVillefranche({Permission.streets}),
      );

      admins.phoneIsAdmin = false;
      expect(container.read(adminProvider), AdminGrants.none);
    });

    test('should hold none when the grants cannot be followed', () async {
      admins = FakeAdminStatus(phoneIsAdmin: true);
      final container = phone();
      await pumpEventQueue();

      admins.fail();

      expect(container.read(adminProvider), AdminGrants.none);
    });

    test('should stop following once the app goes', () async {
      final container = phone();
      await pumpEventQueue();

      container.dispose();

      expect(admins.isFollowed, isFalse);
    });
  });

  group('openSectorPermissionsProvider', () {
    test(
      'should give the permissions held in the open secteur\'s CS',
      () async {
        store = FakeMySectorsStore(
          valueOf(MySectors.none.remember(sector49).open(sector49.id)),
        );
        admins = FakeAdminStatus(
          phoneGrants: AdminGrants(
            centres: {
              csVillefranche.key: {Permission.teams, Permission.sectors},
              valueOf(RescueCentre.create('CS Gleizé')).key: {
                Permission.streets,
              },
            },
          ),
        );
        final container = phone();
        await pumpEventQueue();

        expect(container.read(openSectorPermissionsProvider), {
          Permission.teams,
          Permission.sectors,
        });
      },
    );

    test('should give none when no secteur is open', () async {
      admins = FakeAdminStatus(phoneIsAdmin: true);
      final container = phone();
      await pumpEventQueue();

      expect(container.read(openSectorPermissionsProvider), isEmpty);
    });
  });

  group('canPrepareStreetsProvider', () {
    ProviderContainer opened(MemberStatus status, AdminGrants grants) {
      final sector = summaryOf('t49', 49, status: status);
      store = FakeMySectorsStore(
        valueOf(MySectors.none.remember(sector).open(sector.id)),
      );
      admins = FakeAdminStatus(phoneGrants: grants);
      return phone();
    }

    test('should let an active member prepare, admin or not', () async {
      final container = opened(MemberStatus.active, AdminGrants.none);
      await pumpEventQueue();

      expect(container.read(canPrepareStreetsProvider), isTrue);
    });

    test('should let an admin visiting prepare with « Rues »', () async {
      final container = opened(
        MemberStatus.visiting,
        grantsInVillefranche({Permission.streets}),
      );
      await pumpEventQueue();

      expect(container.read(canPrepareStreetsProvider), isTrue);
    });

    test('should not let an admin visiting prepare without « Rues »', () async {
      final container = opened(
        MemberStatus.visiting,
        grantsInVillefranche({
          Permission.campaign,
          Permission.sectors,
          Permission.teams,
        }),
      );
      await pumpEventQueue();

      expect(container.read(canPrepareStreetsProvider), isFalse);
    });

    test('should let the phone prepare its own streets with no secteur '
        'open', () async {
      final container = phone();
      await pumpEventQueue();

      expect(container.read(canPrepareStreetsProvider), isTrue);
    });
  });
}
