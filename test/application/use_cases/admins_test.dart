import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/application/use_cases/admins.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';

/// The 12 of the CS Villefranche as « Toutes les tournées » lists it.
TourneeOverview overview12({bool callerIsActive = false}) => TourneeOverview(
  id: TourneeId('t12'),
  number: tournee12.number,
  centre: csVillefranche,
  campaign: campaign2026,
  activeMembers: 3,
  pendingRequests: 1,
  callerIsActive: callerIsActive,
);

void main() {
  group('ObserveAdminStatus', () {
    test(
      'should tell whether the phone is an admin, then each change',
      () async {
        final admins = FakeAdminStatus();
        final seen = <bool>[];
        final listening = ObserveAdminStatus(admins)().listen(seen.add);
        addTearDown(listening.cancel);
        await pumpEventQueue();

        admins.phoneIsAdmin = true;
        await pumpEventQueue();

        expect(seen, [false, true]);
      },
    );
  });

  group('IsMemberAdmin', () {
    test('should say whether a member is an admin', () async {
      final admins = FakeAdminStatus(admins: [manuId]);

      expect(await IsMemberAdmin(admins)(manuId), isTrue);
      expect(await IsMemberAdmin(admins)(leaId), isFalse);
      expect(admins.asked, [manuId, leaId]);
    });
  });

  group('ListAllTournees', () {
    late FakeTourneeDirectory directory;

    setUp(() {
      directory = FakeTourneeDirectory()..overviews = [overview12()];
    });

    test(
      'should list every tournée of the app for the admin signed in',
      () async {
        final account = FakeMemberAccount(signedInMember: samId);

        final all = valueOf(await ListAllTournees(directory, account)());

        expect(all, [overview12()]);
        expect(directory.allAsked, [samId]);
      },
    );

    test('should sign in first when the phone has no account yet', () async {
      final account = FakeMemberAccount(nextMember: samId);

      valueOf(await ListAllTournees(directory, account)());

      expect(account.signInCalls, 1);
      expect(directory.allAsked, [samId]);
    });

    test('should tell when the phone cannot sign in', () async {
      final account = FakeMemberAccount();

      final failure = failureOf(await ListAllTournees(directory, account)());

      expect(failure, DirectoryFailure.noNetwork);
      expect(directory.allAsked, isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      directory.offline = true;

      final failure = failureOf(
        await ListAllTournees(
          directory,
          FakeMemberAccount(signedInMember: samId),
        )(),
      );

      expect(failure, DirectoryFailure.noNetwork);
    });
  });

  group('OpenAsAdmin', () {
    late FakeMyTourneesStore store;

    setUp(() {
      store = FakeMyTourneesStore(
        valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
      );
    });

    test('should keep a tournée the admin is not in as visited, and open '
        'it', () async {
      final opened = await OpenAsAdmin(store)(overview12());

      final visited = summaryOf('t12', 12, status: MemberStatus.visiting);
      expect(opened, visited);
      expect(store.myTournees.tournees, [tournee49, visited]);
      expect(store.myTournees.currentId, TourneeId('t12'));
      expect(store.saves, hasLength(1));
    });

    test(
      'should keep a tournée the admin is in as theirs, and open it',
      () async {
        final opened = await OpenAsAdmin(store)(
          overview12(callerIsActive: true),
        );

        expect(opened, tournee12);
        expect(store.myTournees.current, tournee12);
      },
    );

    test('should replace what the phone kept of the tournée', () async {
      store.myTournees = MyTournees.none.remember(
        summaryOf('t12', 12, status: MemberStatus.pending),
      );

      final opened = await OpenAsAdmin(store)(overview12());

      expect(store.myTournees.tournees, [opened]);
      expect(opened.status, MemberStatus.visiting);
    });

    test(
      'should take the number, centre and campaign the server gives',
      () async {
        final moved = TourneeOverview(
          id: TourneeId('t12'),
          number: tournee12.number,
          centre: csVillefranche,
          campaign: campaign2027,
          activeMembers: 0,
          pendingRequests: 0,
          callerIsActive: false,
        );

        final opened = await OpenAsAdmin(store)(moved);

        expect(
          opened,
          TourneeSummary(
            id: TourneeId('t12'),
            number: tournee12.number,
            centre: csVillefranche,
            campaign: campaign2027,
            status: MemberStatus.visiting,
          ),
        );
      },
    );
  });
}
