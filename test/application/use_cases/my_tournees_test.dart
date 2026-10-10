import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MyTournees _manusPhone() => valueOf(
  MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7)
      .open(tournee49.id),
);

void main() {
  late FakeMyTourneesStore store;

  setUp(() => store = FakeMyTourneesStore(_manusPhone()));

  group('ReadMyTournees', () {
    test('should give the tournées the phone keeps', () {
      expect(ReadMyTournees(store)(), _manusPhone());
    });
  });

  group('ObserveMyTournees', () {
    test('should give each list saved', () async {
      final seen = <MyTournees>[];
      ObserveMyTournees(store)().listen(seen.add);

      await store.save(MyTournees.none);

      expect(seen, [MyTournees.none]);
    });
  });

  group('OpenTournee', () {
    test('should open the tournée and keep it for the next launch', () async {
      final opened = await OpenTournee(store)(tournee12.id);

      expect(valueOf(opened), tournee12);
      expect(store.saves.single.current, tournee12);
      expect(store.saves.single.tournees, [tournee49, tournee12, tournee7]);
    });

    test('should save nothing when the tournée is already open', () async {
      final opened = await OpenTournee(store)(tournee49.id);

      expect(valueOf(opened), tournee49);
      expect(store.saves, isEmpty);
    });

    test(
      'should refuse and save nothing when the request is pending',
      () async {
        final opened = await OpenTournee(store)(tournee7.id);

        expect(failureOf(opened), OpenTourneeFailure.requestPending);
        expect(store.saves, isEmpty);
      },
    );

    test(
      'should refuse and save nothing when the tournée is unknown',
      () async {
        final opened = await OpenTournee(store)(TourneeId('t99'));

        expect(failureOf(opened), OpenTourneeFailure.unknownTournee);
        expect(store.saves, isEmpty);
      },
    );
  });

  group('WatchJoinRequest', () {
    test('should follow the request the signed-in member sent', () async {
      final directory = FakeTourneeDirectory();
      final watch = WatchJoinRequest(
        directory,
        FakeMemberAccount(signedInMember: manuId),
      );

      final first = watch(tournee7.id).first;
      directory.answer(tournee7.id, MemberStatus.active);

      expect(await first, MemberStatus.active);
      expect(directory.watched, [(tournee7.id, manuId)]);
    });

    test('should follow nothing when the phone never signed in', () async {
      final directory = FakeTourneeDirectory();
      final watch = WatchJoinRequest(directory, FakeMemberAccount());

      expect(await watch(tournee7.id).isEmpty, isTrue);
      expect(directory.watched, isEmpty);
    });
  });

  group('SettleJoinRequest', () {
    test(
      'should make the tournée a member one when accepted, closed',
      () async {
        await SettleJoinRequest(store)(tournee7.id, MemberStatus.active);

        expect(store.saves.single.tournees, [
          tournee49,
          tournee12,
          tournee7.accepted(),
        ]);
        expect(store.saves.single.current, tournee49);
      },
    );

    test('should forget the tournée when the request is gone', () async {
      await SettleJoinRequest(store)(tournee7.id, null);

      expect(store.saves.single.tournees, [tournee49, tournee12]);
      expect(store.saves.single.current, tournee49);
    });

    test('should save nothing while the request is pending', () async {
      await SettleJoinRequest(store)(tournee7.id, MemberStatus.pending);

      expect(store.saves, isEmpty);
    });

    test(
      'should save nothing when the tournée is no longer a request',
      () async {
        await SettleJoinRequest(store)(tournee12.id, null);
        await SettleJoinRequest(store)(tournee12.id, MemberStatus.active);
        await SettleJoinRequest(store)(TourneeId('t99'), null);

        expect(store.saves, isEmpty);
      },
    );
  });
}
