// « Quelle maison ? » (PLAN §5.20, #168): the tournée with a house to
// mark and the secteur's streets, filtered by name.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/which_house_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Saturday's tournée, one house to mark.
final saturday = RoundSummary(
  id: RoundId('sat'),
  startedAt: startedAt,
  endedAt: endedAt,
  housesVisited: 23,
  totals: DonationTotals.of([cash(1000)]),
  donations: [cash(1000)],
  housesToMark: 1,
);

/// Allée des Pins: number 1 done, number 3 to do.
final pins = valueOf(
  Street.create(
    id: StreetId('allee-des-pins'),
    name: 'Allée des Pins',
    commune: villefranche,
    houses: [
      House(number: n('1'), status: VisitStatus.done, lastChange: paulAtThree),
      House(number: n('3')),
    ],
  ),
);

void main() {
  late FakeRoundLedger ledger;
  late FakeStreetRepository streets;
  late ProviderContainer container;

  setUp(() {
    ledger = FakeRoundLedger()..have(sector49Id, year2026, saturday);
    streets = FakeStreetRepository([lilas, pins]);
    container = ProviderContainer(
      overrides: [
        roundLedgerProvider.overrideWithValue(ledger),
        openRoundStoreProvider.overrideWithValue(FakeOpenRoundStore(null)),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
        ),
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        streetRepositoryProvider.overrideWithValue(streets),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(collecteProvider, (_, _) {})
      ..listen(whichHouseProvider(RoundId('sat')), (_, _) {});
  });

  Future<WhichHouseView> shown() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(whichHouseProvider(RoundId('sat')));
  }

  final pinsRow = StreetRow(
    id: StreetId('allee-des-pins'),
    name: 'Allée des Pins',
    done: 1,
    total: 2,
  );

  test('should show the tournée and the streets in French order with '
      'their progress', () async {
    final view = await shown();

    expect(view.startedAt, startedAt.toLocal());
    expect(view.housesToMark, 1);
    expect(view.streets, [
      pinsRow,
      StreetRow(id: lilasId, name: 'Rue des Lilas', done: 1, total: 4),
    ]);
  });

  test('should keep the streets whose name holds what is typed', () async {
    await shown();

    container.read(whichHouseProvider(RoundId('sat')).notifier).filter('allee');

    expect((await shown()).streets, [pinsRow]);
  });

  test('should follow the houses to mark of the tournée', () async {
    await shown();

    await ledger.settleForgottenHouse(
      sector49Id,
      year2026,
      RoundId('sat'),
      ForgottenHouse.ignored,
    );

    expect((await shown()).housesToMark, 0);
  });

  test('should show no tournée once it is gone from Collecte', () async {
    container.listen(whichHouseProvider(RoundId('nope')), (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final view = container.read(whichHouseProvider(RoundId('nope')));
    expect(view.startedAt, isNull);
    expect(view.housesToMark, 0);
    expect(view.streets, hasLength(2));
  });

  test('should show no street when the streets cannot be read', () async {
    streets.watchError = StateError('removed');
    container.invalidate(whichHouseProvider(RoundId('sat')));

    expect((await shown()).streets, isEmpty);
  });

  test('should equal a view of the same values only', () async {
    final view = await shown();
    final same = WhichHouseView(
      startedAt: view.startedAt,
      housesToMark: 1,
      streets: view.streets,
    );

    expect(view, same);
    expect(view.hashCode, same.hashCode);
    expect(
      view,
      isNot(
        WhichHouseView(
          startedAt: view.startedAt,
          housesToMark: 2,
          streets: view.streets,
        ),
      ),
    );
  });
}
