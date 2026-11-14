// « Corriger la tournée » (PLAN §5.20, #168) through its notifier, with the
// ledger and the phone's secteurs faked.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/correct_round_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/correct_round_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show twoPm;

/// Saturday's tournée: 23 houses, 10 € in cash, 20 € by cheque, a free
/// calendar, the dons kept.
final saturday = RoundSummary(
  id: RoundId('sat'),
  startedAt: startedAt,
  endedAt: endedAt,
  housesVisited: 23,
  totals: DonationTotals.of([cash(1000), cheque(2000), offered]),
  donations: [cash(1000), cheque(2000), offered],
);

/// Friday's, validated before #168: no list.
final friday = RoundSummary(
  id: RoundId('fri'),
  startedAt: startedAt.subtract(const Duration(days: 1)),
  endedAt: endedAt.subtract(const Duration(days: 1)),
  housesVisited: 14,
  totals: DonationTotals.of([card(750)]),
);

void main() {
  late FakeRoundLedger ledger;
  late ProviderContainer container;

  void phoneWith({bool open = true}) {
    ledger = FakeRoundLedger()
      ..have(sector49Id, year2026, saturday)
      ..have(sector49Id, year2026, friday);
    var mine = MySectors.none.remember(sector12);
    if (open) mine = valueOf(mine.remember(sector49).open(sector49.id));
    container = ProviderContainer(
      overrides: [
        roundLedgerProvider.overrideWithValue(ledger),
        openRoundStoreProvider.overrideWithValue(FakeOpenRoundStore(null)),
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore(mine)),
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        streetRepositoryProvider.overrideWithValue(repositoryWithLilas()),
        clockProvider.overrideWithValue(clockAtTwo()),
        identityProvider.overrideWithValue(leaOnThePhone()),
      ],
    );
    addTearDown(container.dispose);
    // As the Collecte screen under it does.
    container.listen(collecteProvider, (_, _) {});
  }

  /// The view of the tournée [id], once « Collecte » is read.
  Future<CorrectRoundShown> opened([String id = 'sat']) async {
    container.listen(correctRoundProvider(RoundId(id)), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(correctRoundProvider(RoundId(id)))
        as CorrectRoundShown;
  }

  CorrectRoundNotifier notifier([String id = 'sat']) =>
      container.read(correctRoundProvider(RoundId(id)).notifier);

  CorrectRoundShown view([String id = 'sat']) =>
      container.read(correctRoundProvider(RoundId(id))) as CorrectRoundShown;

  test('should show the tournée on « Don par don », its dons newest '
      'first, nothing changed', () async {
    phoneWith();

    final shown = await opened();

    expect(shown.startedAt, startedAt.toLocal());
    expect(shown.endedAt, endedAt.toLocal());
    expect(shown.housesVisited, 23);
    expect(shown.tab, CorrectionTab.donByDon);
    expect(shown.hasList, isTrue);
    expect(shown.donations, [
      const DonationRow(index: 2, donation: offered),
      DonationRow(index: 1, donation: cheque(2000)),
      DonationRow(index: 0, donation: cash(1000)),
    ]);
    expect(shown.before, saturday.totals);
    expect(shown.after, saturday.totals);
    expect(shown.changed, isFalse);
    expect(shown.canSave, isTrue);
    expect(shown.cash, const MethodDraft(count: 1, cents: 1000));
    expect(shown.cheque, const MethodDraft(count: 1, cents: 2000));
    expect(shown.card, const MethodDraft(count: 0, cents: 0));
    expect(shown.of(PaymentMethod.cheque), shown.cheque);
    expect(shown.of(PaymentMethod.cash), shown.cash);
    expect(shown.of(PaymentMethod.card), shown.card);
    expect(shown.free, 1);
    expect(shown.freeFailure, isNull);
  });

  test('should open a tournée without a list on « Totaux », with no '
      'switch', () async {
    phoneWith();

    final shown = await opened('fri');
    notifier('fri').selectTab(CorrectionTab.donByDon);

    expect(shown.tab, CorrectionTab.totals);
    expect(shown.hasList, isFalse);
    expect(shown.donations, isEmpty);
    expect(view('fri').tab, CorrectionTab.totals);
  });

  test(
    'should have nothing to correct for a tournée not in Collecte',
    () async {
      phoneWith();
      container.listen(correctRoundProvider(RoundId('nope')), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(correctRoundProvider(RoundId('nope'))),
        const CorrectRoundGone(),
      );
      expect(await notifier('nope').save(), isFalse);
    },
  );

  group('Don par don', () {
    test('should add, change and remove dons, the totals following', () async {
      phoneWith();
      await opened();

      notifier()
        ..addDonation(card(500))
        ..changeDonation(0, cash(1500))
        ..removeDonation(2);

      expect(view().donations, [
        DonationRow(index: 2, donation: card(500)),
        DonationRow(index: 1, donation: cheque(2000)),
        DonationRow(index: 0, donation: cash(1500)),
      ]);
      expect(
        view().after,
        DonationTotals.of([cash(1500), cheque(2000), card(500)]),
      );
      expect(view().changed, isTrue);
      expect(view().before, saturday.totals);
    });

    test('should ignore a don at a place past the list', () async {
      phoneWith();
      final before = await opened();

      notifier()
        ..changeDonation(3, cash(1))
        ..changeDonation(-1, cash(1))
        ..removeDonation(3)
        ..removeDonation(-1);

      expect(view(), before);
    });

    test('should not take more than $mostDonations dons', () async {
      phoneWith();
      await opened();

      for (var i = 0; i < mostDonations - 3; i++) {
        notifier().addDonation(offered);
      }
      expect(view().canSave, isTrue);
      notifier().addDonation(offered);
      expect(view().canSave, isFalse);
      expect(await notifier().save(), isFalse);
      expect(ledger.corrected, isEmpty);
    });

    test('should save the list, stamped with the clock', () async {
      phoneWith();
      await opened();
      notifier().addDonation(card(500));

      expect(await notifier().save(), isTrue);

      expect(ledger.corrected.single.$3, RoundId('sat'));
      expect(
        ledger.corrected.single.$4,
        RoundCorrected(
          totals: DonationTotals.of([
            cash(1000),
            cheque(2000),
            offered,
            card(500),
          ]),
          donations: [cash(1000), cheque(2000), offered, card(500)],
          correctedAt: twoPm,
          housesAdded: 1,
        ),
      );
    });

    test('should be changed back to unchanged when the list is as it '
        'was', () async {
      phoneWith();
      await opened();

      notifier()
        ..addDonation(card(500))
        ..removeDonation(3);

      expect(view().changed, isFalse);
    });
  });

  group('Totaux', () {
    setUp(phoneWith);

    test('should take the figures typed, the list left aside', () async {
      await opened();
      notifier()
        ..selectTab(CorrectionTab.totals)
        ..setCount(PaymentMethod.card, 2)
        ..setAmount(PaymentMethod.card, '15,50')
        ..setFree(3);

      final shown = view();
      expect(shown.tab, CorrectionTab.totals);
      expect(shown.card, const MethodDraft(count: 2, cents: 1550));
      expect(shown.free, 3);
      expect(
        shown.after,
        DonationTotals(
          cash: MethodTotal(count: 1, cents: 1000),
          cheque: MethodTotal(count: 1, cents: 2000),
          card: MethodTotal(count: 2, cents: 1550),
          free: 3,
        ),
      );
      expect(shown.changed, isTrue);
      expect(shown.canSave, isTrue);
      expect(shown.donations, hasLength(3));
    });

    test('should be unchanged with the figures as they were', () async {
      await opened();
      notifier()
        ..selectTab(CorrectionTab.totals)
        ..setAmount(PaymentMethod.cash, '10');

      expect(view().changed, isFalse);
      expect(view().after, saturday.totals);
    });

    test('should say a count without money, or money without a count, and '
        'grey « Enregistrer »', () async {
      await opened();
      notifier()
        ..selectTab(CorrectionTab.totals)
        ..setCount(PaymentMethod.cheque, 0)
        ..setCount(PaymentMethod.card, 8);

      final shown = view();
      expect(shown.cheque.totalFailure, TotalFailure.countMissing);
      expect(shown.cheque.isFaulty, isTrue);
      expect(shown.card.totalFailure, TotalFailure.amountMissing);
      expect(shown.cash.isFaulty, isFalse);
      expect(shown.canSave, isFalse);
      expect(await notifier().save(), isFalse);
      expect(ledger.corrected, isEmpty);
    });

    test('should say an amount it cannot read, counted as none', () async {
      await opened();
      notifier()
        ..selectTab(CorrectionTab.totals)
        ..setAmount(PaymentMethod.cash, 'abc');

      final shown = view();
      expect(
        shown.cash,
        const MethodDraft(
          count: 1,
          cents: null,
          amountFailure: AmountFailure.notValid,
        ),
      );
      expect(shown.cash.isFaulty, isTrue);
      expect(shown.after.cash, MethodTotal(count: 1, cents: 0));
      expect(shown.canSave, isFalse);
    });

    test('should refuse more than 9 999 calendars offered', () async {
      await opened();
      notifier()
        ..selectTab(CorrectionTab.totals)
        ..setFree(10000);

      expect(view().freeFailure, TotalFailure.tooMany);
      expect(view().canSave, isFalse);
      notifier().setFree(9999);
      expect(view().canSave, isTrue);
    });

    test('should save the totals typed', () async {
      await opened();
      notifier()
        ..selectTab(CorrectionTab.totals)
        ..setCount(PaymentMethod.cash, 2)
        ..setAmount(PaymentMethod.cash, '30');

      expect(await notifier().save(), isTrue);

      final change = ledger.corrected.single.$4;
      expect(change.donations, isNull);
      expect(change.totals.cash, MethodTotal(count: 2, cents: 3000));
      expect(change.housesAdded, 1);
    });

    test('should keep each tab its own draft', () async {
      await opened();
      notifier()
        ..addDonation(card(500))
        ..selectTab(CorrectionTab.totals);

      expect(view().after, saturday.totals);
      expect(view().changed, isFalse);
      notifier().selectTab(CorrectionTab.donByDon);
      expect(view().changed, isTrue);
    });
  });

  test(
    'should keep what is typed when a teammate changes the tournée',
    () async {
      phoneWith();
      await opened();
      notifier().addDonation(card(500));

      await ledger.correct(
        sector49Id,
        year2026,
        RoundId('sat'),
        RoundCorrected(
          totals: DonationTotals.none,
          donations: const <Donation>[],
          correctedAt: twoPm,
          housesAdded: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(view().donations, hasLength(4));
      expect(view().before, saturday.totals);
    },
  );

  test('should save nothing once the secteur is closed', () async {
    phoneWith();
    await opened();
    notifier().addDonation(card(500));
    container.listen(currentSectorProvider, (_, _) {});
    await container.read(mySectorsProvider.notifier).open(sector12.id);

    expect(await notifier().save(), isFalse);
    expect(ledger.corrected, isEmpty);
  });

  test('should equal a view of the same values only', () async {
    phoneWith();
    final shown = await opened();
    notifier().setFree(2);

    expect(shown, isNot(view()));
    expect(shown.hashCode, isNot(view().hashCode));
    notifier().setFree(1);
    expect(view(), shown);
    expect(view().hashCode, shown.hashCode);
    expect(
      const CorrectRoundGone().hashCode,
      const CorrectRoundGone().hashCode,
    );
    expect(
      const MethodDraft(count: 1, cents: 2).toString(),
      'MethodDraft(1, 2, null, null)',
    );
    expect(
      const MethodDraft(count: 1, cents: 2).hashCode,
      const MethodDraft(count: 1, cents: 2).hashCode,
    );
  });
}
