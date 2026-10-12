import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/application/use_cases/create_tournee.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';

void main() {
  final csAnse = valueOf(RescueCentre.create('CS Anse'));
  final number12 = valueOf(TourneeNumber.create(12));

  group('ListRescueCentres', () {
    test('should give the centres the app knows', () async {
      final directory = FakeTourneeDirectory()
        ..centres = [csAnse, csVillefranche];

      expect(valueOf(await ListRescueCentres(directory)()), [
        csAnse,
        csVillefranche,
      ]);
    });

    test('should fail offline', () async {
      final directory = FakeTourneeDirectory()..offline = true;

      expect(
        failureOf(await ListRescueCentres(directory)()),
        DirectoryFailure.noNetwork,
      );
    });
  });

  group('CheckTourneeTaken', () {
    test('should say a number taken in the same station is taken', () async {
      final directory = FakeTourneeDirectory()
        ..taken.add((csVillefranche.key, number49));
      final cis = valueOf(RescueCentre.create('CIS Villefranche'));

      expect(
        valueOf(await CheckTourneeTaken(directory)(cis, number49)),
        isTrue,
      );
      expect(directory.takenAsked, [(cis, number49)]);
    });

    test('should say another number is free', () async {
      final directory = FakeTourneeDirectory()
        ..taken.add((csVillefranche.key, number49));

      expect(
        valueOf(await CheckTourneeTaken(directory)(csVillefranche, number12)),
        isFalse,
      );
    });

    test('should fail offline', () async {
      final directory = FakeTourneeDirectory()..offline = true;

      expect(
        failureOf(await CheckTourneeTaken(directory)(csVillefranche, number49)),
        DirectoryFailure.noNetwork,
      );
    });
  });

  group('CreateTournee', () {
    late FakeTourneeRepository tournees;
    late FakeMemberAccount account;
    late FakeMyTourneesStore store;
    final now = DateTime.utc(2026, 10, 9, 18, 30);

    setUp(() {
      tournees = FakeTourneeRepository();
      account = FakeMemberAccount(signedInMember: manuId);
      store = FakeMyTourneesStore();
    });

    /// « Créer » the 49 of the CS Villefranche, campaign 2026, as Manu; the
    /// code drawn is `234567` (the indexes of `2`…`7` in the alphabet).
    Future<Tournee> create() async =>
        valueOf(await _create(tournees, account, store, now));

    test('should store the tournée with Manu as its only member', () async {
      final created = await create();

      expect(tournees.added, [created]);
      expect(created.id, TourneeId('tournee-1'));
      expect(created.number, number49);
      expect(created.centre, csVillefranche);
      expect(created.currentCampaign, campaign2026);
      expect(created.joinCode, codeOf('234567'));
      expect(created.createdBy, manuId);
      expect(created.createdAt, now);
      expect(created.members, [
        Member(
          id: manuId,
          name: nameOf('Manu'),
          requestedAt: now,
          acceptance: ChangeStamp(by: manuId, at: now),
        ),
      ]);
    });

    test(
      'should keep the tournée among Manu\'s and open it when it is created',
      () async {
        store = FakeMyTourneesStore(MyTournees.none.remember(tournee12));

        final created = await create();

        final summary = TourneeSummary(
          id: created.id,
          number: number49,
          centre: csVillefranche,
          campaign: campaign2026,
          status: MemberStatus.active,
        );
        expect(store.saves, [
          valueOf(
            MyTournees.none
                .remember(tournee12)
                .remember(summary)
                .open(created.id),
          ),
        ]);
      },
    );

    test(
      'should give the code the server stored when the one drawn was taken',
      () async {
        tournees.addCodeTaken = firstCode;

        final created = await create();

        expect(created.joinCode, firstCode);
      },
    );

    test('should sign in first when the phone has no account yet', () async {
      account = FakeMemberAccount(nextMember: leaId);

      final created = await create();

      expect(account.signInCalls, 1);
      expect(created.createdBy, leaId);
    });

    test(
      'should fail and store nothing when the sign-in finds no network',
      () async {
        account = FakeMemberAccount();

        final failure = failureOf(await _create(tournees, account, store, now));

        expect(failure, CreateTourneeFailure.noNetwork);
        expect(tournees.added, isEmpty);
        expect(store.saves, isEmpty);
      },
    );

    test('should fail and open nothing when the number is taken', () async {
      tournees.addFailure = AddTourneeFailure.alreadyExists;

      final failure = failureOf(await _create(tournees, account, store, now));

      expect(failure, CreateTourneeFailure.alreadyExists);
      expect(store.saves, isEmpty);
    });

    test(
      'should fail and open nothing when the server cannot be reached',
      () async {
        tournees.addFailure = AddTourneeFailure.noNetwork;

        final failure = failureOf(await _create(tournees, account, store, now));

        expect(failure, CreateTourneeFailure.noNetwork);
        expect(store.saves, isEmpty);
      },
    );
  });
}

Future<Result<Tournee, CreateTourneeFailure>> _create(
  FakeTourneeRepository tournees,
  FakeMemberAccount account,
  FakeMyTourneesStore store,
  DateTime now,
) =>
    CreateTournee(
      tournees,
      account,
      store,
      FakeClock(now),
      FakeIdGenerator('tournee'),
      ScriptedRandom([23, 24, 25, 26, 27, 28]),
    )(
      centre: csVillefranche,
      number: number49,
      campaign: campaign2026,
      creatorName: nameOf('Manu'),
    );
