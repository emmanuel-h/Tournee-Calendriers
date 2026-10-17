// Whether the phone, or a member, is an administrator (PLAN §5.12), against
// an in-memory Firestore (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_admin_status.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<List<bool>> seenWhile(
    FirestoreAdminStatus admins,
    Future<void> Function() change,
  ) async {
    final seen = <bool>[];
    final subscription = admins.watchIsAdmin().listen(seen.add);
    await pumpEventQueue();
    await change();
    await pumpEventQueue();
    await subscription.cancel();
    return seen;
  }

  group('watchIsAdmin', () {
    test('should say the signed-in member is an admin while their admin '
        'document is there', () async {
      await db.doc('admins/uid-sam').set(<String, Object?>{});
      final admins = FirestoreAdminStatus(
        db,
        FakeMemberAccount(signedInMember: samId),
      );

      final seen = await seenWhile(admins, () async {});

      expect(seen, [true]);
    });

    test('should follow the admin document added, then removed', () async {
      final admins = FirestoreAdminStatus(
        db,
        FakeMemberAccount(signedInMember: samId),
      );

      final seen = await seenWhile(admins, () async {
        await db.doc('admins/uid-sam').set(<String, Object?>{});
        await pumpEventQueue();
        await db.doc('admins/uid-sam').delete();
      });

      expect(seen, [false, true, false]);
    });

    test('should say no before the phone has an account, then follow the '
        'member once signed in', () async {
      await db.doc('admins/uid-sam').set(<String, Object?>{});
      final account = FakeMemberAccount(nextMember: samId);
      final admins = FirestoreAdminStatus(db, account);

      final seen = await seenWhile(admins, account.signInIfNeeded);

      expect(seen, [false, true]);
      expect(account.isWaitedFor, isFalse);
    });

    test('should stop waiting for a sign-in once nobody listens', () async {
      final account = FakeMemberAccount();
      final admins = FirestoreAdminStatus(db, account);

      final seen = await seenWhile(admins, () async {});

      expect(seen, [false]);
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
