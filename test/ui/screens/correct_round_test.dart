// Correcting a validated tournée and marking a forgotten house, from
// « Collecte » (PLAN §5.20, #168; mockups CashCorrect, CashCorrectOpen,
// RoundCorrectDons, RoundCorrect, RoundCorrectConfirm, MarkForgotten,
// MarkForgottenStreet): the critical interactions only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show n, twoPm;
import '../support/app_overrides.dart';
import '../support/navigation.dart';

const _nbsp = '\u00A0';

/// Saturday 24 October, 14:05 → 18:20: 23 houses, its dons kept (10 € and
/// 20 € in cash, 5 € by cheque, a free calendar), corrected by « Totaux »
/// (one cheque more) so the list differs, one house to mark.
final _saturday = RoundSummary(
  id: RoundId('sat'),
  startedAt: DateTime(2026, 10, 24, 14, 5).toUtc(),
  endedAt: DateTime(2026, 10, 24, 18, 20).toUtc(),
  housesVisited: 23,
  totals: DonationTotals(
    cash: MethodTotal(count: 2, cents: 3000),
    cheque: MethodTotal(count: 2, cents: 1000),
    card: MethodTotal.none,
    free: 1,
  ),
  donations: [cash(1000), cash(2000), cheque(500), offered],
  correctedAt: DateTime(2026, 10, 25, 9).toUtc(),
  housesToMark: 1,
);

/// Monday 26 October, validated on this phone, not yet sent.
final _monday = UnsentRound(
  sector: sector49.id,
  campaign: sector49.campaign,
  summary: RoundSummary(
    id: RoundId('mon'),
    startedAt: DateTime(2026, 10, 26, 14).toUtc(),
    endedAt: DateTime(2026, 10, 26, 17, 10).toUtc(),
    housesVisited: 18,
    totals: DonationTotals.of([cash(16000)]),
    donations: [cash(16000)],
  ),
);

void main() {
  late FakeRoundLedger ledger;
  late FakeStreetRepository streets;

  /// « Collecte 2026 » of the 49 on Léa's phone, Saturday in the ledger
  /// ([summary] instead when given), the Rue des Lilas on the phone.
  Future<void> pumpCollecte(
    WidgetTester tester, {
    RoundSummary? summary,
    List<UnsentRound> unsent = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    ledger = FakeRoundLedger()
      ..have(sector49.id, sector49.campaign, summary ?? _saturday)
      // The phone's sends never reach the server here.
      ..server = Completer();
    streets = repositoryWithLilas();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
          sectors: FakeSectorRepository([team()]),
          ledger: ledger,
          rounds: FakeOpenRoundStore(null, unsent),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(Scaffold).first)),
      AppRoutes.collecte,
    );
    await tester.pumpAndSettle();
  }

  /// The texts of [finder] and under it, joined by « | ».
  String textsOf(WidgetTester tester, Finder finder) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: finder, matching: find.byType(Text), matchRoot: true),
    ))
      text.data,
  ].join(' | ');

  final saturdayRow = find.byKey(const ValueKey('collecte.round.sat'));

  Future<void> unfold(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: saturdayRow,
        matching: find.byKey(const Key('collecte.round.toggle')),
      ),
    );
    await tester.pumpAndSettle();
  }

  RoundSummary stored() =>
      ledger.recorded.singleWhere((each) => each.$3.id == _saturday.id).$3;

  group('Collecte', () {
    testWidgets('should show a corrected tournée and its house to mark, '
        'and take it off on « Ignorer »', (tester) async {
      await pumpCollecte(tester);

      expect(
        textsOf(tester, saturdayRow),
        'Sam. 24 oct. · 14:05 → 18:20 | 23${_nbsp}maisons, 4${_nbsp}dons | '
        '✎ Corrigée le 25 oct. | 40$_nbsp€ | ▸ | ⚠ 1${_nbsp}maison à marquer | '
        'Marquer une maison | Ignorer',
      );
      expect(
        find.bySemanticsLabel(
          'Sam. 24 oct. · 14:05 → 18:20, 40$_nbsp€, afficher le détail, '
          '✎ Corrigée le 25 oct.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Les dons ne sont jamais associés à une adresse.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('collecte.round.ignore')));
      await tester.pumpAndSettle();

      expect(ledger.settled.single.$4, ForgottenHouse.ignored);
      expect(find.byKey(const Key('collecte.round.toMark')), findsNothing);
      expect(find.byKey(const Key('collecte.round.markHouse')), findsNothing);
    });

    testWidgets('should unfold its free calendars, its dons read-only, the '
        'list differing and « ✎ Corriger »', (tester) async {
      await pumpCollecte(tester);

      await unfold(tester);

      final detail = find.byKey(const Key('collecte.round.methods'));
      expect(
        textsOf(tester, detail),
        'Espèces | 2${_nbsp}dons | 30$_nbsp€ | Chèques | 2${_nbsp}dons | '
        '10$_nbsp€ | Carte bancaire | 0${_nbsp}don | 0$_nbsp€ | '
        'Calendriers offerts | 1 |  | Voir les 3 dons | ⚠ | '
        'La liste des dons ne correspond plus aux totaux. | ✎ Corriger',
      );

      await tester.ensureVisible(find.byKey(const Key('collecte.round.dons')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collecte.round.dons')));
      await tester.pumpAndSettle();

      expect(find.text('Dons de la tournée'), findsOneWidget);
      expect(
        textsOf(tester, find.byKey(const Key('collecteDons.totals'))),
        '3${_nbsp}dons · 35$_nbsp€',
      );
      expect(
        textsOf(tester, find.byKey(const Key('collecteDons.list'))),
        'Calendrier offert | 5$_nbsp€ | Chèque | 20$_nbsp€ | Espèces | '
        '10$_nbsp€ | Espèces',
      );
      // Read-only: a tap opens nothing.
      await tester.tap(find.text('Chèque'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le don'), findsNothing);
    });

    testWidgets('should offer no « ✎ Corriger » on a tournée not yet '
        'sent', (tester) async {
      await pumpCollecte(tester, unsent: [_monday]);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('collecte.unsent.mon')),
          matching: find.byKey(const Key('collecte.round.toggle')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collecte.round.methods')), findsOneWidget);
      expect(find.byKey(const Key('collecte.round.correct')), findsNothing);
      expect(find.byKey(const Key('collecte.round.dons')), findsNothing);
    });
  });

  group('Corriger la tournée', () {
    Future<void> openCorrect(WidgetTester tester) async {
      await unfold(tester);
      await tester.ensureVisible(
        find.byKey(const Key('collecte.round.correct')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collecte.round.correct')));
      await tester.pumpAndSettle();
    }

    testWidgets('should correct the totals: a faulty line greys '
        '« Enregistrer », then before → after, « Correction enregistrée. »', (
      tester,
    ) async {
      await pumpCollecte(tester);
      await openCorrect(tester);
      expect(
        textsOf(tester, find.byKey(const Key('correct.subtitle'))),
        'Sam. 24 oct. · 14:05 → 18:20 · 23${_nbsp}maisons',
      );
      await tester.tap(find.byKey(const Key('correct.tab.totals')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('correct.cash.amount')))
            .controller!
            .text,
        '30,00',
      );

      await tester.enterText(
        find.byKey(const Key('correct.card.amount')),
        '20',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('⚠ Au moins 1${_nbsp}don pour 20$_nbsp€.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const Key('correct.save')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(const Key('correct.card.count')), '1');
      await tester.pumpAndSettle();
      expect(find.textContaining('Au moins'), findsNothing);
      expect(
        textsOf(tester, find.byKey(const Key('correct.total'))),
        '5${_nbsp}dons · 60$_nbsp€',
      );
      await tester.tap(find.byKey(const Key('correct.save')));
      await tester.pumpAndSettle();

      expect(find.text('Corriger la tournée\u00a0?'), findsOneWidget);
      expect(
        find.text(
          'Total\u00a0: 4${_nbsp}dons, 40$_nbsp€\n→ 5${_nbsp}dons, 60$_nbsp€',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Tout le secteur verra les nouveaux chiffres.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('correct.confirm.ok')));
      await tester.pumpAndSettle();

      expect(find.text('Correction enregistrée.'), findsOneWidget);
      expect(find.text('Collecte 2026'), findsOneWidget);
      final correction = ledger.corrected.single.$4;
      expect(correction.donations, isNull);
      expect(correction.totals.card, MethodTotal(count: 1, cents: 2000));
      expect(correction.correctedAt, twoPm);
      expect(correction.housesAdded, 1);
      expect(stored().housesToMark, 2);
    });

    testWidgets('should change a don of the list and save it with its '
        'totals', (tester) async {
      await pumpCollecte(tester);
      await openCorrect(tester);
      expect(
        textsOf(tester, find.byKey(const Key('correct.donsLine'))),
        '3${_nbsp}dons · 35$_nbsp€ · touchez un don pour le changer.',
      );

      // Newest first: the cheque is the second row.
      await tester.tap(find.byKey(const ValueKey('correct.don.1')));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le don'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('donation.amount')), '15');
      await tester.tap(find.byKey(const Key('donation.validate')));
      await tester.pumpAndSettle();

      expect(
        textsOf(tester, find.byKey(const Key('correct.donsLine'))),
        '3${_nbsp}dons · 45$_nbsp€ · touchez un don pour le changer.',
      );
      await tester.tap(find.byKey(const Key('correct.save')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Total\u00a0: 4${_nbsp}dons, 40$_nbsp€\n→ 3${_nbsp}dons, 45$_nbsp€',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('correct.confirm.ok')));
      await tester.pumpAndSettle();

      final correction = ledger.corrected.single.$4;
      expect(correction.donations, [
        cash(1000),
        cash(2000),
        cheque(1500),
        offered,
      ]);
      expect(stored().listDiffersFromTotals, isFalse);
      expect(find.text('Correction enregistrée.'), findsOneWidget);
    });

    testWidgets('should add a don and remove another', (tester) async {
      await pumpCollecte(tester);
      await openCorrect(tester);

      await tester.tap(find.byKey(const Key('correct.add')));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau don'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('donation.method.card')));
      await tester.enterText(find.byKey(const Key('donation.amount')), '5');
      await tester.tap(find.byKey(const Key('donation.validate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('correct.don.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('donation.remove')));
      await tester.pumpAndSettle();

      expect(
        textsOf(tester, find.byKey(const Key('correct.dons'))),
        '5$_nbsp€ | Carte bancaire | 5$_nbsp€ | Chèque | 20$_nbsp€ | '
        'Espèces | 10$_nbsp€ | Espèces',
      );
    });

    testWidgets('should go back without asking when nothing changed', (
      tester,
    ) async {
      await pumpCollecte(tester);
      await openCorrect(tester);

      await tester.tap(find.byKey(const Key('correct.save')));
      await tester.pumpAndSettle();

      expect(find.text('Corriger la tournée\u00a0?'), findsNothing);
      expect(find.text('Collecte 2026'), findsOneWidget);
      expect(find.text('Correction enregistrée.'), findsNothing);
      expect(ledger.corrected, isEmpty);
    });

    testWidgets('should keep the correction when « Annuler » is tapped', (
      tester,
    ) async {
      await pumpCollecte(tester);
      await openCorrect(tester);
      await tester.tap(find.byKey(const Key('correct.tab.totals')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('correct.free')), '2');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('correct.save')));
      await tester.pumpAndSettle();
      // Only the free calendars changed: the same total, then their line.
      expect(
        find.text(
          'Total : 4${_nbsp}dons, 40$_nbsp€\n→ 4${_nbsp}dons, 40$_nbsp€\n'
          'Calendriers offerts : 1 → 2',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('correct.confirm.cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Corriger la tournée'), findsOneWidget);
      expect(ledger.corrected, isEmpty);
    });

    testWidgets('should offer « Totaux » only on a tournée validated '
        'before #168', (tester) async {
      await pumpCollecte(
        tester,
        summary: RoundSummary(
          id: RoundId('sat'),
          startedAt: _saturday.startedAt,
          endedAt: _saturday.endedAt,
          housesVisited: 23,
          totals: _saturday.totals,
        ),
      );
      await unfold(tester);
      expect(find.byKey(const Key('collecte.round.dons')), findsNothing);
      expect(find.byKey(const Key('collecte.round.differs')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('collecte.round.correct')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collecte.round.correct')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('correct.tabs')), findsNothing);
      expect(find.byKey(const Key('correct.totals')), findsOneWidget);
      expect(find.byKey(const Key('correct.add')), findsNothing);
      await tester.enterText(find.byKey(const Key('correct.cash.count')), '');
      await tester.pumpAndSettle();
      expect(
        find.text('⚠ Au moins 1${_nbsp}don pour 30$_nbsp€.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('correct.cash.count')), '8');
      await tester.enterText(find.byKey(const Key('correct.cash.amount')), '');
      await tester.pumpAndSettle();
      expect(find.text('⚠ Un montant pour 8${_nbsp}dons.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('correct.cash.amount')),
        '9000',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('⚠ 1${_nbsp}000$_nbsp€ au plus par don.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('correct.cash.amount')), ',');
      await tester.pumpAndSettle();
      expect(find.text('Entrez un montant valide.'), findsNothing);
      expect(find.text('⚠ Entrez un montant valide.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('correct.free')), '');
      await tester.pumpAndSettle();
      expect(find.text('⚠ 9${_nbsp}999 au plus.'), findsNothing);
    });
  });

  group('A forgotten house', () {
    Future<void> openWhichHouse(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('collecte.round.markHouse')));
      await tester.pumpAndSettle();
    }

    testWidgets('should list the streets, then mark the house tapped with '
        'no tournée on, back to Collecte', (tester) async {
      await pumpCollecte(tester);
      await openWhichHouse(tester);

      expect(find.text('Quelle maison\u00a0?'), findsOneWidget);
      expect(
        textsOf(tester, find.byKey(const Key('whichHouse.subtitle'))),
        'Tournée du sam. 24 oct. · 1${_nbsp}maison à marquer',
      );
      expect(
        find.text(
          'Choisissez la rue de la maison oubliée, puis touchez la maison.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('whichHouse.search')), 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('Rue des Lilas'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('whichHouse.search')),
        'lilas',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rue des Lilas'));
      await tester.pumpAndSettle();

      expect(
        textsOf(tester, find.byKey(const Key('forgotten.subtitle'))),
        'Villefranche-sur-Saône · 1/4',
      );
      expect(
        find.text('Touchez la maison oubliée\u00a0: elle sera marquée ✓ Fait.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('street.tile.7')));
      await tester.pumpAndSettle();

      expect(find.text('Collecte 2026'), findsOneWidget);
      expect(find.text('N° 7 rue des Lilas marquée ✓.'), findsOneWidget);
      expect(houseOf(streets[lilasId]!, '7').status, VisitStatus.done);
      expect(stored().housesVisited, 24);
      expect(stored().housesToMark, 0);
    });

    testWidgets('should say a door already done, then mark another, in the '
        'building\'s grid', (tester) async {
      await pumpCollecte(tester);
      await openWhichHouse(tester);
      await tester.tap(find.text('Rue des Lilas'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('street.tile.8')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grid.forgotten')), findsOneWidget);
      expect(find.byKey(const Key('grid.manage')), findsNothing);
      await tester.tap(find.byKey(ValueKey('grid.door.${rdc('01').id}')));
      await tester.pumpAndSettle();
      expect(find.text('Porte 01\u00a0: déjà marquée ✓.'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('grid.door.${rdc('02').id}')));
      await tester.pumpAndSettle();

      expect(
        find.text('Porte 02 du 8 rue des Lilas marquée ✓.'),
        findsOneWidget,
      );
      expect(
        houseOf(streets[lilasId]!, '8').building!.dwellingAt(rdc('02'))!.status,
        VisitStatus.done,
      );
      expect(ledger.settled.single.$4, ForgottenHouse.marked);
    });

    testWidgets('should say a house already done, and leave when nothing is '
        'left to mark', (tester) async {
      await pumpCollecte(tester);
      await openWhichHouse(tester);
      await tester.tap(find.text('Rue des Lilas'));
      await tester.pumpAndSettle();
      // Marked as done by a teammate meanwhile, and the tournée settled on
      // another phone.
      final (marked, change) = valueOf(
        streets[lilasId]!.markHouse(
          n('7'),
          VisitStatus.done,
          by: leaId,
          at: twoPm,
        ),
      );
      await streets.save(marked, change);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('street.tile.7')));
      await tester.pumpAndSettle();
      expect(find.text('N° 7\u00a0: déjà marquée ✓.'), findsOneWidget);

      await ledger.settleForgottenHouse(
        sector49.id,
        sector49.campaign,
        RoundId('sat'),
        ForgottenHouse.ignored,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('street.tile.5')));
      await tester.pumpAndSettle();

      expect(find.text('Quelle maison\u00a0?'), findsOneWidget);
      expect(streets.saved, hasLength(1));
    });
  });
}
