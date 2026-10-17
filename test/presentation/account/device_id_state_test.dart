import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/account/device_id_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';

/// A Firebase uid: 28 letters and digits.
final uid = MemberId('x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');

void main() {
  group('DeviceIdShown', () {
    test('should shorten the id to its first and last four characters', () {
      final shown = DeviceIdShown(uid.value, isAdmin: false);

      expect(shown.id, 'x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');
      expect(shown.short, 'x7Fq…9kP2');
      expect(shown.isAdmin, isFalse);
    });

    test('should show an id of nine characters or fewer whole', () {
      expect(
        const DeviceIdShown('abcdefghi', isAdmin: false).short,
        'abcdefghi',
      );
      expect(
        const DeviceIdShown('abcdefghij', isAdmin: false).short,
        'abcd…ghij',
      );
    });

    test('should be equal when the id and the admin flag are', () {
      expect(
        const DeviceIdShown('abc', isAdmin: true),
        const DeviceIdShown('abc', isAdmin: true),
      );
      expect(
        const DeviceIdShown('abc', isAdmin: true).hashCode,
        const DeviceIdShown('abc', isAdmin: true).hashCode,
      );
      expect(
        const DeviceIdShown('abc', isAdmin: true),
        isNot(const DeviceIdShown('abd', isAdmin: true)),
      );
      expect(
        const DeviceIdShown('abc', isAdmin: true),
        isNot(const DeviceIdShown('abc', isAdmin: false)),
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

      expect(
        container.read(deviceIdProvider),
        DeviceIdShown(uid.value, isAdmin: false),
      );
    });

    test('should say administrateur once the phone is known as one', () async {
      account = FakeMemberAccount(signedInMember: uid);
      admins = FakeAdminStatus(phoneIsAdmin: true);
      final container = open();
      await pumpEventQueue();

      expect(
        container.read(deviceIdProvider),
        DeviceIdShown(uid.value, isAdmin: true),
      );
    });

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
