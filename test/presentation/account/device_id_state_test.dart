import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/account/device_id_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';

/// A Firebase uid: 28 letters and digits.
final uid = MemberId('x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');

void main() {
  group('DeviceIdShown', () {
    test('should keep the whole id and the role', () {
      final shown = DeviceIdShown(uid.value, role: AdminRole.superAdmin);

      expect(shown.id, 'x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');
      expect(shown.role, AdminRole.superAdmin);
    });

    test('should have no role unless given one', () {
      expect(const DeviceIdShown('abc').role, AdminRole.none);
    });

    test('should be equal when the id and the role are', () {
      expect(
        const DeviceIdShown('abc', role: AdminRole.admin),
        const DeviceIdShown('abc', role: AdminRole.admin),
      );
      expect(
        const DeviceIdShown('abc', role: AdminRole.admin).hashCode,
        const DeviceIdShown('abc', role: AdminRole.admin).hashCode,
      );
      expect(
        const DeviceIdShown('abc', role: AdminRole.admin),
        isNot(const DeviceIdShown('abd', role: AdminRole.admin)),
      );
      expect(
        const DeviceIdShown('abc', role: AdminRole.admin),
        isNot(const DeviceIdShown('abc', role: AdminRole.superAdmin)),
      );
    });
  });

  group('deviceIdProvider', () {
    late FakeMemberAccount account;
    late FakeAdminStatus admins;

    ProviderContainer open() {
      final container = ProviderContainer(
        overrides: [
          memberAccountProvider.overrideWithValue(account),
          adminStatusProvider.overrideWithValue(admins),
        ],
      );
      addTearDown(container.dispose);
      // Kept alive as the screen keeps it while it shows.
      container.listen(deviceIdProvider, (_, _) {});
      return container;
    }

    setUp(() => admins = FakeAdminStatus());

    test('should show the id of a phone that has its account', () async {
      account = FakeMemberAccount(signedInMember: uid);
      final container = open();
      await pumpEventQueue();

      expect(container.read(deviceIdProvider), DeviceIdShown(uid.value));
    });

    test('should say administrateur once the phone is known as one', () async {
      account = FakeMemberAccount(signedInMember: uid);
      admins = FakeAdminStatus(phoneIsAdmin: true);
      final container = open();
      await pumpEventQueue();

      expect(
        container.read(deviceIdProvider),
        DeviceIdShown(uid.value, role: AdminRole.admin),
      );
    });

    test(
      'should say super administrateur for the holder of « admins »',
      () async {
        account = FakeMemberAccount(signedInMember: uid);
        admins = FakeAdminStatus(
          phoneGrants: AdminGrants(global: {GlobalPermission.admins}),
        );
        final container = open();
        await pumpEventQueue();

        expect(
          container.read(deviceIdProvider),
          DeviceIdShown(uid.value, role: AdminRole.superAdmin),
        );
      },
    );

    test('should wait while the phone signs in, signing in itself', () async {
      account = FakeMemberAccount(nextMember: uid)..gate = Completer<void>();
      final container = open();
      await pumpEventQueue();

      expect(container.read(deviceIdProvider), const DeviceIdSigningIn());
      expect(account.signInCalls, 1);
    });

    test('should say there is no account yet when offline', () async {
      account = FakeMemberAccount();
      final container = open();
      await pumpEventQueue();

      expect(container.read(deviceIdProvider), const DeviceIdOffline());
    });
  });
}
