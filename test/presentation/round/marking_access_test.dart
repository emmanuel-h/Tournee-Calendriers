import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/round/marking_access.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show lea;

// Houses are marked only during a tournée (PLAN §5.14, « Marking only in a
// tournée »).

void main() {
  group('MarkingAccess.of', () {
    test('should open the picker while a tournée is on', () {
      final on = RoundOn(
        startedAt: startedAt,
        now: endedAt,
        housesVisited: 3,
        totals: DonationTotals.of([cash(1000)]),
        donations: const [],
      );

      expect(MarkingAccess.of(on), MarkingAccess.open);
    });

    test('should ask to start a tournée when none is on and the member may '
        'start one', () {
      expect(
        MarkingAccess.of(const RoundOff(canStart: true)),
        MarkingAccess.startRoundFirst,
      );
    });

    test('should keep marking to the members when the phone may not start '
        'a tournée (an admin visiting)', () {
      expect(
        MarkingAccess.of(const RoundOff(canStart: false)),
        MarkingAccess.membersOnly,
      );
    });

    test('should allow nothing yet while the tournée is being read', () {
      expect(MarkingAccess.of(const RoundLoading()), MarkingAccess.notYetKnown);
    });
  });

  group('markingAccessProvider', () {
    late ProviderContainer container;

    /// A phone where [open] is the secteur shown, no tournée on.
    void phoneWith(SectorSummary open) {
      container = ProviderContainer(
        overrides: [
          openRoundStoreProvider.overrideWithValue(FakeOpenRoundStore()),
          roundLedgerProvider.overrideWithValue(FakeRoundLedger()),
          clockProvider.overrideWithValue(FakeClock(startedAt)),
          idGeneratorProvider.overrideWithValue(FakeIdGenerator('round')),
          mySectorsStoreProvider.overrideWithValue(
            FakeMySectorsStore(
              valueOf(MySectors.none.remember(open).open(open.id)),
            ),
          ),
          sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
          streetRepositoryProvider.overrideWithValue(FakeStreetRepository()),
          identityProvider.overrideWithValue(FakeIdentity(lea)),
        ],
      );
      addTearDown(container.dispose);
      // `listen` keeps the auto-disposed provider alive, as a screen does.
      container.listen(markingAccessProvider, (_, _) {});
    }

    Future<MarkingAccess> settled() async {
      await Future<void>.delayed(Duration.zero);
      return container.read(markingAccessProvider);
    }

    test('should open marking once the member starts a tournée', () async {
      phoneWith(sector49);
      expect(await settled(), MarkingAccess.startRoundFirst);

      await container.read(roundProvider.notifier).start();

      expect(await settled(), MarkingAccess.open);
    });

    test('should keep marking to the members when an admin visits', () async {
      phoneWith(sector12Visited);

      expect(await settled(), MarkingAccess.membersOnly);
    });
  });
}
