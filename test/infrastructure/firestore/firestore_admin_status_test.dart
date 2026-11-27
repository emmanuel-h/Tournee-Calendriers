// What the phone may do as an administrator, and whether a member is one
// (PLAN §5.12, §5.23), against an in-memory Firestore (fake_cloud_firestore,
// PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_admin_status.dart';

import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<List<AdminGrants>> seenWhile(
    FirestoreAdminStatus admins,
    Future<void> Function() change,
  ) async {
    final seen = <AdminGrants>[];
    final subscription = admins.watchGrants().listen(seen.add);
    await pumpEventQueue();
    await change();
    await pumpEventQueue();
    await subscription.cancel();
    return seen;
  }

  final teams = {
    'centres': {
      'villefranche': ['teams'],
    },
  };
  final teamsGrants = grantsInVillefranche({Permission.teams});

  group('watchGrants', () {
    test('should give the signed-in member the grants of their admin '
        'document', () async {
      await db.doc('admins/uid-sam').set(teams);
      final admins = FirestoreAdminStatus(
        db,
        FakeMemberAccount(signedInMember: samId),
      );

      final seen = await seenWhile(admins, () async {});

      expect(seen, [teamsGrants]);
    });

    test('should follow the admin document added, changed, then '
        'removed', () async {
      final admins = FirestoreAdminStatus(
        db,
        FakeMemberAccount(signedInMember: samId),
      );

      final seen = await seenWhile(admins, () async {
        await db.doc('admins/uid-sam').set(teams);
        await pumpEventQueue();
        await db.doc('admins/uid-sam').set({
          'centres': {
            'villefranche': ['teams', 'streets'],
          },
          'global': ['admins'],
        });
        await pumpEventQueue();
        await db.doc('admins/uid-sam').delete();
      });

      expect(seen, [
        AdminGrants.none,
        teamsGrants,
        AdminGrants(
          centres: {
            csVillefranche.key: {Permission.teams, Permission.streets},
          },
          global: {GlobalPermission.admins},
        ),
        AdminGrants.none,
      ]);
    });

    test('should give none before the phone has an account, then follow '
        'the member once signed in', () async {
      await db.doc('admins/uid-sam').set(teams);
      final account = FakeMemberAccount(nextMember: samId);
      final admins = FirestoreAdminStatus(db, account);

      final seen = await seenWhile(admins, account.signInIfNeeded);

      expect(seen, [AdminGrants.none, teamsGrants]);
      expect(account.isWaitedFor, isFalse);
    });

    test('should stop waiting for a sign-in once nobody listens', () async {
      final account = FakeMemberAccount();
      final admins = FirestoreAdminStatus(db, account);

      final seen = await seenWhile(admins, () async {});

      expect(seen, [AdminGrants.none]);
      expect(account.isWaitedFor, isFalse);
    });
  });

  group('isAdmin', () {
    test('should say a member with an admin document is an admin', () async {
      await db.doc('admins/uid-manu').set(<String, Object?>{});

      final status = FirestoreAdminStatus(db, FakeMemberAccount());

      expect(await status.isAdmin(manuId), isTrue);
      expect(await status.isAdmin(leaId), isFalse);
    });

    test('should say no when it cannot be told', () async {
      final status = FirestoreAdminStatus(db, FakeMemberAccount());
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('admins/uid-manu'))
          .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );

      expect(await status.isAdmin(manuId), isFalse);
    });
  });
}
