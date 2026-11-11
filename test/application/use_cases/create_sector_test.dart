import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/application/use_cases/create_sector.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';

void main() {
  final csAnse = valueOf(RescueCentre.create('CS Anse'));
  final number12 = valueOf(SectorNumber.create(12));

  group('ListRescueCentres', () {
    test('should give the centres the app knows', () async {
      final directory = FakeSectorDirectory()
        ..centres = [csAnse, csVillefranche];

      expect(valueOf(await ListRescueCentres(directory)()), [
        csAnse,
        csVillefranche,
      ]);
    });

    test('should fail offline', () async {
      final directory = FakeSectorDirectory()..offline = true;

      expect(
        failureOf(await ListRescueCentres(directory)()),
        DirectoryFailure.noNetwork,
      );
    });
  });

  group('CheckSectorTaken', () {
    test('should say a number taken in the same station is taken', () async {
      final directory = FakeSectorDirectory()
        ..taken.add((csVillefranche.key, number49));
      final cis = valueOf(RescueCentre.create('CIS Villefranche'));

      expect(valueOf(await CheckSectorTaken(directory)(cis, number49)), isTrue);
      expect(directory.takenAsked, [(cis, number49)]);
    });

    test('should say another number is free', () async {
      final directory = FakeSectorDirectory()
        ..taken.add((csVillefranche.key, number49));

      expect(
        valueOf(await CheckSectorTaken(directory)(csVillefranche, number12)),
        isFalse,
      );
    });

    test('should fail offline', () async {
      final directory = FakeSectorDirectory()..offline = true;

      expect(
        failureOf(await CheckSectorTaken(directory)(csVillefranche, number49)),
        DirectoryFailure.noNetwork,
      );
    });
  });

  group('CreateSector', () {
    late FakeSectorRepository sectors;
    late FakeMemberAccount account;
    late FakeMySectorsStore store;
    final now = DateTime.utc(2026, 10, 9, 18, 30);

    setUp(() {
      sectors = FakeSectorRepository();
      account = FakeMemberAccount(signedInMember: manuId);
      store = FakeMySectorsStore();
    });

    /// « Créer » the 49 of the CS Villefranche, campaign 2026, as Manu; the
    /// code drawn is `234567` (the indexes of `2`…`7` in the alphabet).
    Future<Sector> create() async =>
        valueOf(await _create(sectors, account, store, now));

    test('should store the tournée with Manu as its only member', () async {
      final created = await create();

      expect(sectors.added, [created]);
      expect(created.id, SectorId('sector-1'));
      expect(created.number, number49);
      expect(created.centre, csVillefranche);
      expect(created.currentCampaign, campaign2026);
      expect(created.joinCode, codeOf('234567'));
      expect(created.createdBy, manuId);
      expect(created.createdAt, now);
      expect(created.communes, [villefrancheCommune, gleizeCommune]);
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
        store = FakeMySectorsStore(MySectors.none.remember(sector12));

        final created = await create();

        final summary = SectorSummary(
          id: created.id,
          number: number49,
          centre: csVillefranche,
          campaign: campaign2026,
          status: MemberStatus.active,
          memberName: nameOf('Manu'),
        );
        expect(store.saves, [
          valueOf(
            MySectors.none
                .remember(sector12)
                .remember(summary)
                .open(created.id),
          ),
        ]);
      },
    );

    test(
      'should give the code the server stored when the one drawn was taken',
      () async {
        sectors.addCodeTaken = firstCode;

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

        final failure = failureOf(await _create(sectors, account, store, now));

        expect(failure, CreateSectorFailure.noNetwork);
        expect(sectors.added, isEmpty);
        expect(store.saves, isEmpty);
      },
    );

    test('should fail and open nothing when the number is taken', () async {
      sectors.addFailure = AddSectorFailure.alreadyExists;

      final failure = failureOf(await _create(sectors, account, store, now));

      expect(failure, CreateSectorFailure.alreadyExists);
      expect(store.saves, isEmpty);
    });

    test(
      'should fail and open nothing when the server cannot be reached',
      () async {
        sectors.addFailure = AddSectorFailure.noNetwork;

        final failure = failureOf(await _create(sectors, account, store, now));

        expect(failure, CreateSectorFailure.noNetwork);
        expect(store.saves, isEmpty);
      },
    );

    test('should fail and open nothing when the server says the creator is '
        'no longer an admin', () async {
      sectors.addFailure = AddSectorFailure.notAdmin;

      final failure = failureOf(await _create(sectors, account, store, now));

      expect(failure, CreateSectorFailure.notAdmin);
      expect(store.saves, isEmpty);
    });
  });
}

Future<Result<Sector, CreateSectorFailure>> _create(
  FakeSectorRepository sectors,
  FakeMemberAccount account,
  FakeMySectorsStore store,
  DateTime now,
) =>
    CreateSector(
      sectors,
      account,
      store,
      FakeClock(now),
      FakeIdGenerator('sector'),
      ScriptedRandom([23, 24, 25, 26, 27, 28]),
    )(
      centre: csVillefranche,
      number: number49,
      campaign: campaign2026,
      creatorName: nameOf('Manu'),
      communes: [villefrancheCommune, gleizeCommune],
    );
