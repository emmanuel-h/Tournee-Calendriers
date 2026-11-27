import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/campaign_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/application/use_cases/campaigns.dart';
import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_campaign_store.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

CampaignYear _year(int value) => valueOf(CampaignYear.create(value));

final _csGleize = valueOf(RescueCentre.create('CS Gleizé'));

/// A secteur of [centre] (the CS Villefranche by default) on [campaign],
/// as « Tous les secteurs » lists it.
SectorOverview _overview(
  String id,
  int number,
  int campaign, {
  RescueCentre? centre,
}) => SectorOverview(
  id: SectorId(id),
  number: valueOf(SectorNumber.create(number)),
  centre: centre ?? csVillefranche,
  campaign: _year(campaign),
  activeMembers: 2,
  pendingRequests: 0,
  callerIsActive: false,
);

/// Rue Gambetta, in the Corbeille since Paul deleted it.
final _gambetta = valueOf(
  Street.create(
    id: StreetId('rue-gambetta'),
    name: 'Rue Gambetta',
    commune: villefranche,
    houses: [seven],
    deletion: ChangeStamp(by: paul, at: threePm),
  ),
);

CampaignRecord _record(int year, {required bool validated}) =>
    CampaignRecord(year: _year(year), hasValidatedRound: validated);

void main() {
  group('RollOverSector', () {
    late FakeCampaignStore store;
    final s49 = SectorId('t49');

    setUp(() {
      store = FakeCampaignStore()
        ..streets[(s49, _year(2026))] = [lilas, _gambetta]
        ..campaigns[s49] = [
          _record(2024, validated: false),
          _record(2025, validated: true),
          _record(2026, validated: true),
          _record(2027, validated: false),
        ];
    });

    Future<Result<void, RollOverFailure>> roll(int from, int to) =>
        RollOverSector(store)(s49, from: _year(from), to: _year(to));

    test('should copy, switch, then drop the past years no longer '
        'kept', () async {
      valueOf(await roll(2026, 2027));

      expect(store.steps, [
        'streetsOf t49 2026',
        'writeCopies t49 2026→2027',
        'switchTo t49 2027',
        'campaignsOf t49',
        'delete t49 [2024, 2025]',
      ]);
    });

    test('should copy the setup of each street, not the streets of the '
        'Corbeille', () async {
      valueOf(await roll(2026, 2027));

      final copy = store.copies[(s49, _year(2027))]!.single;
      expect(copy.id, lilasId);
      expect(copy.houses, lilas.forNextCampaign()!.houses);
      expect(copy.houses, isNot(lilas.houses));
    });

    test('should move to any later year, from the year it works on', () async {
      valueOf(await roll(2025, 2027));

      expect(store.steps.take(3), [
        'streetsOf t49 2025',
        'writeCopies t49 2025→2027',
        'switchTo t49 2027',
      ]);
    });

    test('should only drop the past years when run again on the year it '
        'moved to', () async {
      valueOf(await roll(2027, 2027));

      expect(store.steps, ['campaignsOf t49', 'delete t49 [2024, 2025]']);
    });

    test('should delete nothing when every past year is kept', () async {
      store.campaigns[s49] = [
        _record(2026, validated: true),
        _record(2027, validated: false),
      ];

      valueOf(await roll(2026, 2027));

      expect(store.steps.last, 'campaignsOf t49');
    });

    test('should never delete the year moved to, nor a later one', () async {
      store.campaigns[s49] = [
        _record(2026, validated: false),
        _record(2027, validated: false),
        _record(2028, validated: false),
      ];

      valueOf(await roll(2026, 2027));

      expect(store.steps.last, 'delete t49 [2026]');
    });

    test('should refuse an earlier year, before any step', () async {
      expect(failureOf(await roll(2026, 2025)), RollOverFailure.notLater);
      expect(store.steps, isEmpty);
    });

    for (final (step, reached) in [
      ('streetsOf t49 2026', 1),
      ('writeCopies t49 2026→2027', 2),
      ('switchTo t49 2027', 3),
      ('campaignsOf t49', 4),
      ('delete t49 [2024, 2025]', 5),
    ]) {
      for (final (failure, expected) in [
        (CampaignFailure.noNetwork, RollOverFailure.noNetwork),
        (CampaignFailure.notAdmin, RollOverFailure.notAdmin),
      ]) {
        test('should stop at « $step » refused with ${failure.name}', () async {
          store.failures[step] = failure;

          expect(failureOf(await roll(2026, 2027)), expected);
          expect(store.steps, hasLength(reached));
          expect(store.steps.last, step);
        });
      }
    }
  });

  group('StartCampaign', () {
    late FakeSectorDirectory directory;
    late FakeMemberAccount account;
    late FakeCampaignStore store;

    final s49 = SectorId('t49');
    final s12 = SectorId('t12');

    setUp(() {
      directory = FakeSectorDirectory()
        ..overviews = [
          _overview('t49', 49, 2026),
          _overview('g3', 3, 2025, centre: _csGleize),
          _overview('t12', 12, 2026),
        ];
      account = FakeMemberAccount(signedInMember: samId);
      store = FakeCampaignStore()
        ..streets[(s49, _year(2026))] = [lilas]
        ..campaigns[s49] = [
          _record(2025, validated: true),
          _record(2026, validated: true),
        ]
        ..campaigns[s12] = [_record(2026, validated: false)];
    });

    Future<Result<void, StartCampaignFailure>> start(
      int year, {
      RescueCentre? centre,
    }) => StartCampaign(directory, account, store)(
      centre ?? csVillefranche,
      _year(year),
    );

    test('should move each secteur of the centre in turn, the others '
        'left alone', () async {
      valueOf(await start(2027));

      expect(store.steps, [
        'streetsOf t49 2026',
        'writeCopies t49 2026→2027',
        'switchTo t49 2027',
        'campaignsOf t49',
        'delete t49 [2025]',
        'streetsOf t12 2026',
        'writeCopies t12 2026→2027',
        'switchTo t12 2027',
        'campaignsOf t12',
        'delete t12 [2026]',
      ]);
      expect(directory.allAsked, [samId]);
      // Only the secteurs of that CS are asked for (PLAN §5.23).
      expect(directory.allCentresAsked, [
        {csVillefranche.key},
      ]);
    });

    test('should find the centre however its name is written', () async {
      valueOf(
        await start(
          2027,
          centre: valueOf(RescueCentre.create('CS de Villefranche')),
        ),
      );

      expect(store.steps, contains('switchTo t12 2027'));
    });

    test('should refuse a centre whose secteurs are on different years, '
        'and do nothing', () async {
      directory.overviews = [
        _overview('t49', 49, 2027),
        _overview('t12', 12, 2026),
      ];

      expect(failureOf(await start(2027)), StartCampaignFailure.mixedYears);
      expect(store.steps, isEmpty);
    });

    test('should refuse a centre without secteur', () async {
      final failure = failureOf(
        await start(2027, centre: valueOf(RescueCentre.create('CS Anse'))),
      );

      expect(failure, StartCampaignFailure.noSector);
      expect(store.steps, isEmpty);
    });

    test('should refuse a year before the centre\'s, and write '
        'nothing', () async {
      expect(failureOf(await start(2025)), StartCampaignFailure.notLater);
      expect(store.steps, isEmpty);
    });

    test('should sign in first when the phone has no account yet', () async {
      account = FakeMemberAccount(nextMember: samId);

      valueOf(await start(2027));

      expect(account.signInCalls, 1);
      expect(directory.allAsked, [samId]);
    });

    test('should fail without network when the phone cannot sign in', () async {
      account = FakeMemberAccount();

      expect(failureOf(await start(2027)), StartCampaignFailure.noNetwork);
      expect(directory.allAsked, isEmpty);
    });

    test('should fail without network when the secteurs cannot be '
        'listed', () async {
      directory.offline = true;

      expect(failureOf(await start(2027)), StartCampaignFailure.noNetwork);
      expect(store.steps, isEmpty);
    });

    test('should fail when the server says the phone is no longer an '
        'admin', () async {
      directory.notAdmin = true;

      expect(failureOf(await start(2027)), StartCampaignFailure.notAdmin);
      expect(store.steps, isEmpty);
    });

    for (final (failure, expected) in [
      (CampaignFailure.noNetwork, StartCampaignFailure.noNetwork),
      (CampaignFailure.notAdmin, StartCampaignFailure.notAdmin),
    ]) {
      test('should stop at the secteur cut off with ${failure.name}, the '
          'ones before it moved', () async {
        store.failures['switchTo t12 2027'] = failure;

        expect(failureOf(await start(2027)), expected);
        expect(store.steps, contains('switchTo t49 2027'));
        expect(store.steps.last, 'switchTo t12 2027');
      });
    }
  });

  group('WatchCampaign', () {
    test('should tell each campaign the server says the secteur works '
        'on', () async {
      final directory = FakeSectorDirectory();
      final heard = <CampaignYear>[];
      final listening = WatchCampaign(directory)(sector49.id).listen(heard.add);
      addTearDown(listening.cancel);

      directory
        ..hearCampaign(sector49.id, _year(2026))
        ..hearCampaign(sector12.id, _year(2028))
        ..hearCampaign(sector49.id, _year(2027));
      await pumpEventQueue();

      expect(heard, [_year(2026), _year(2027)]);
    });
  });

  group('FollowCampaign', () {
    late FakeMySectorsStore store;

    setUp(() {
      store = FakeMySectorsStore(
        valueOf(
          MySectors.none
              .remember(sector49)
              .remember(sector12)
              .remember(sector7)
              .open(sector49.id),
        ),
      );
    });

    test('should move the secteur to the later campaign, still open', () async {
      final followed = await FollowCampaign(store)(sector49.id, campaign2027);

      final mine = store.mySectors;
      expect(followed, sector49.followedTo(campaign2027));
      expect(mine.find(sector49.id)!.campaign, campaign2027);
      expect(mine.currentId, sector49.id);
      expect(mine.find(sector12.id)!.campaign, campaign2026);
      expect(store.saves, hasLength(1));
    });

    test('should change nothing when the phone has the year already', () async {
      expect(await FollowCampaign(store)(sector49.id, campaign2026), isNull);
      expect(store.saves, isEmpty);
    });

    test(
      'should change nothing for a secteur the phone does not know',
      () async {
        final unknown = SectorId('t99');

        expect(await FollowCampaign(store)(unknown, campaign2027), isNull);
        expect(store.saves, isEmpty);
      },
    );

    test('should change nothing for a request still pending', () async {
      expect(await FollowCampaign(store)(sector7.id, campaign2027), isNull);
      expect(store.saves, isEmpty);
    });
  });
}
