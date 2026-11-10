import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/map/map_legend.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/dons_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/round_recap_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';

// The tournée on Accueil, « Dons de la tournée », « Nouveau don » /
// « Modifier le don » and « Bilan de la tournée » (PLAN §5.13, §5.14,
// mockups RunStart, RunHome, RunDons, RunDon, RunRecap).

const _nbsp = ' ';

/// Saturday 24 October 2026, 14:05 and 18:20 on the phone's clock,
/// whatever its time zone.
final _start = DateTime(2026, 10, 24, 14, 5).toUtc();
final _now = DateTime(2026, 10, 24, 18, 20).toUtc();

/// The 49's tournée started at [_start], 3 houses visited, with, in the
/// order added: 10 € in cash, a free calendar, 20 € by cheque, 7,50 € by
/// card.
Round _round({List<Donation>? donations}) => Round.restore(
  id: roundId,
  sector: sector49Id,
  campaign: year2026,
  startedAt: _start,
  housesVisited: 3,
  donations: donations ?? [cash(1000), offered, cheque(2000), card(750)],
);

Finder _key(String key) => find.byKey(ValueKey(key));

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

void main() {
  late FakeOpenRoundStore rounds;
  late FakeClock clock;
  late FakeRoundLedger ledger;

  /// Léa's phone with [open] open (the 49 by default), [round] on (none
  /// by default) and [also] known; the clock reads [_now].
  Future<void> pumpHome(
    WidgetTester tester, {
    Round? round,
    SectorSummary? open,
    List<SectorSummary> also = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rounds = FakeOpenRoundStore(round);
    final opened = open ?? sector49;
    var mine = MySectors.none.remember(opened);
    for (final sector in also) {
      mine = mine.remember(sector);
    }
    clock = FakeClock(_now);
    ledger = FakeRoundLedger();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(valueOf(mine.open(opened.id))),
          rounds: rounds,
          ledger: ledger,
          clock: clock,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(location).ignore();
    await tester.pumpAndSettle();
  }

  List<Donation> dons() => rounds.openRound!.donations;

  group('Accueil', () {
    testWidgets('should offer « Commencer une tournée » to a member of the '
        'team, and start one offline on a tap', (tester) async {
      await pumpHome(tester);
      expect(_key('round.band'), findsNothing);

      await tap(tester, _key('round.start'));

      expect(_key('round.start'), findsNothing);
      expect(
        _text(tester, 'round.band.since'),
        "En tournée · moins d'une minute",
      );
      expect(_text(tester, 'round.band.totals'), '0${_nbsp}don · 0$_nbsp€ ›');
      expect(rounds.openRound!.sector, sector49Id);
      expect(rounds.openRound!.startedAt, _now);
    });

    testWidgets('should not offer it to an admin visiting the secteur', (
      tester,
    ) async {
      await pumpHome(tester, open: sector12Visited);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_key('round.start'), findsNothing);
      expect(_key('round.band'), findsNothing);
    });

    testWidgets('should say a tournée is on in another secteur when one is '
        'started there', (tester) async {
      await pumpHome(tester, open: sector12, also: [sector49], round: _round());

      await tap(tester, _key('round.start'));

      expect(
        find.text('Une tournée est déjà en cours dans un autre secteur.'),
        findsOneWidget,
      );
      expect(_key('round.band'), findsNothing);
    });

    testWidgets('should show the tournée on: since when, its dons and their '
        'money', (tester) async {
      await pumpHome(tester, round: _round());

      expect(_key('round.start'), findsNothing);
      expect(
        _text(tester, 'round.band.since'),
        'En tournée · 4${_nbsp}h${_nbsp}15',
      );
      expect(
        _text(tester, 'round.band.totals'),
        '3${_nbsp}dons · 37,50$_nbsp€ ›',
      );
      expect(find.bySemanticsLabel('Terminer la tournée'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'En tournée depuis 4${_nbsp}h${_nbsp}15, 3${_nbsp}dons, '
          '37,50$_nbsp€. Voir les dons',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should show the top bar, and no band, while no tournée is '
        'on', (tester) async {
      await pumpHome(tester);

      expect(_key('home.sector'), findsOneWidget);
      expect(_key('home.settings'), findsOneWidget);
      expect(_key('round.band'), findsNothing);
    });

    testWidgets('should put the band in the top bar\'s place during a '
        'tournée: no secteur switch, no Secteur, no ⚙', (tester) async {
      await pumpHome(tester, round: _round());

      expect(find.byType(AppBar), findsNothing);
      expect(_key('home.sector'), findsNothing);
      expect(_key('home.settings'), findsNothing);
      // At the top of the screen, its Surface under the status bar too.
      expect(tester.getRect(_key('round.band')).top, 0);
      expect(
        tester.getRect(_key('round.band')).bottom,
        lessThan(tester.getRect(find.byType(MapLegend)).top),
      );
    });

    testWidgets('should keep « depuis » up as time goes by', (tester) async {
      await pumpHome(tester, round: _round());
      clock.time = _now.add(const Duration(minutes: 5));

      await tester.pump(const Duration(seconds: 30));

      expect(
        _text(tester, 'round.band.since'),
        'En tournée · 4${_nbsp}h${_nbsp}20',
      );
    });

    testWidgets('should open « Dons de la tournée » from « Voir les dons »', (
      tester,
    ) async {
      await pumpHome(tester, round: _round());

      await tap(tester, _key('round.band.dons'));

      expect(find.byType(DonsScreen), findsOneWidget);
    });

    testWidgets('should open the « Bilan » from « Terminer »', (tester) async {
      await pumpHome(tester, round: _round());

      await tap(tester, _key('round.finish'));

      expect(find.byType(RoundRecapScreen), findsOneWidget);
    });
  });

  group('Dons de la tournée', () {
    Future<void> pumpDons(WidgetTester tester, {Round? round}) async {
      await pumpHome(tester, round: round ?? _round());
      await push(tester, AppRoutes.roundDons);
    }

    /// What the [position]-th row shows, top first.
    String rowText(WidgetTester tester, int position) => [
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: _key('dons.row.$position'),
          matching: find.byType(Text),
        ),
      ))
        text.data,
    ].join(' | ');

    testWidgets('should list the dons newest first under their totals', (
      tester,
    ) async {
      await pumpDons(tester);

      expect(_text(tester, 'dons.totals'), '3${_nbsp}dons · 37,50$_nbsp€');
      expect(rowText(tester, 0), '7,50$_nbsp€ | Carte bancaire');
      expect(rowText(tester, 1), '20$_nbsp€ | Chèque');
      expect(rowText(tester, 2), 'Calendrier offert');
      expect(rowText(tester, 3), '10$_nbsp€ | Espèces');
    });

    testWidgets('should say when there is no don yet', (tester) async {
      await pumpDons(tester, round: _round(donations: []));

      expect(find.text("Aucun don pour l'instant."), findsOneWidget);
      expect(_text(tester, 'dons.totals'), '0${_nbsp}don · 0$_nbsp€');
    });

    testWidgets('should open « Modifier le don » on the don tapped, and '
        'change that one', (tester) async {
      await pumpDons(tester);

      // The second row shown is the third don added: 20 € by cheque.
      await tap(tester, _key('dons.row.1'));

      expect(find.text('Modifier le don'), findsOneWidget);
      expect(
        tester
            .getSemantics(_key('donation.method.cheque'))
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      expect(
        tester.widget<TextField>(_key('donation.amount')).controller!.text,
        '20',
      );
      await tap(tester, _key('donation.method.cash'));
      await tester.enterText(_key('donation.amount'), '25');
      await tap(tester, _key('donation.validate'));

      expect(find.text('Modifier le don'), findsNothing);
      expect(dons(), [cash(1000), offered, cash(2500), card(750)]);
      expect(rowText(tester, 1), '25$_nbsp€ | Espèces');
    });

    testWidgets('should open a don with cents written with a comma', (
      tester,
    ) async {
      await pumpDons(tester);

      await tap(tester, _key('dons.row.0'));

      expect(
        tester.widget<TextField>(_key('donation.amount')).controller!.text,
        '7,50',
      );
    });

    testWidgets('should open a free calendar empty, on Espèces', (
      tester,
    ) async {
      await pumpDons(tester);

      await tap(tester, _key('dons.row.2'));

      expect(
        tester.widget<TextField>(_key('donation.amount')).controller!.text,
        isEmpty,
      );
      expect(
        tester
            .getSemantics(_key('donation.method.cash'))
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
    });

    testWidgets('should remove the don tapped with « Supprimer ce don »', (
      tester,
    ) async {
      await pumpDons(tester);

      await tap(tester, _key('dons.row.3'));
      await tap(tester, _key('donation.remove'));

      expect(dons(), [offered, cheque(2000), card(750)]);
      expect(_text(tester, 'dons.totals'), '2${_nbsp}dons · 27,50$_nbsp€');
    });

    testWidgets('should change nothing on « Annuler »', (tester) async {
      await pumpDons(tester);
      await tap(tester, _key('dons.row.0'));
      await tester.enterText(_key('donation.amount'), '99');

      await tap(tester, _key('donation.cancel'));

      expect(find.text('Modifier le don'), findsNothing);
      expect(dons(), _round().donations);
    });

    testWidgets('should refuse an amount under « Montant », the sheet still '
        'open', (tester) async {
      await pumpDons(tester);
      await tap(tester, _key('dons.row.0'));
      await tester.enterText(_key('donation.amount'), '0,001');

      await tap(tester, _key('donation.validate'));

      expect(
        find.text('Deux chiffres après la virgule au plus.'),
        findsOneWidget,
      );
      expect(find.text('Modifier le don'), findsOneWidget);
      expect(dons(), _round().donations);
    });

    testWidgets('should add a don from « Nouveau don », empty, on Espèces, '
        'its field heard as « Montant »', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDons(tester);

      await tap(tester, _key('dons.add'));

      expect(find.text('Nouveau don'), findsOneWidget);
      expect(_key('donation.remove'), findsNothing);
      expect(
        tester.getSemantics(_key('donation.amount')).label,
        contains('Montant'),
      );
      await tester.enterText(_key('donation.amount'), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(dons().last, cash(1200));
      expect(_text(tester, 'dons.totals'), '4${_nbsp}dons · 49,50$_nbsp€');
      semantics.dispose();
    });

    testWidgets('should refuse an empty amount in « Nouveau don »', (
      tester,
    ) async {
      await pumpDons(tester);
      await tap(tester, _key('dons.add'));

      await tap(tester, _key('donation.validate'));

      expect(find.text('Écrivez un montant.'), findsOneWidget);
      expect(dons(), _round().donations);
    });

    testWidgets('should show nothing to change once the tournée is '
        'validated', (tester) async {
      await pumpDons(tester);

      await rounds.clear();
      await tester.pumpAndSettle();

      expect(_key('dons.list'), findsNothing);
      expect(_key('dons.add'), findsNothing);
      expect(_key('dons.totals'), findsNothing);
    });
  });

  group('Bilan de la tournée', () {
    Future<void> pumpRecap(WidgetTester tester, {Round? round}) async {
      await pumpHome(tester, round: round ?? _round());
      await tap(tester, _key('round.finish'));
    }

    String lineText(WidgetTester tester, String key) => [
      for (final text in tester.widgetList<Text>(
        find.descendant(of: _key(key), matching: find.byType(Text)),
      ))
        text.data,
    ].join(' | ');

    testWidgets('should show the day, the times, the three figures and the '
        'money per method', (tester) async {
      await pumpRecap(tester);

      expect(
        _text(tester, 'recap.when'),
        'Samedi 24 octobre, de 14${_nbsp}h${_nbsp}05 à 18${_nbsp}h${_nbsp}20',
      );
      expect(lineText(tester, 'recap.houses'), '3 | maisons visitées');
      expect(lineText(tester, 'recap.dons'), '3 | dons');
      expect(lineText(tester, 'recap.free'), '1 | calendrier offert');
      expect(
        lineText(tester, 'recap.cash'),
        'Espèces | 1${_nbsp}don | 10$_nbsp€',
      );
      expect(
        lineText(tester, 'recap.cheque'),
        'Chèques | 1${_nbsp}don | 20$_nbsp€',
      );
      expect(
        lineText(tester, 'recap.card'),
        'Carte bancaire | 1${_nbsp}don | 7,50$_nbsp€',
      );
      expect(
        lineText(tester, 'recap.total'),
        'Total | 3${_nbsp}dons | 37,50$_nbsp€',
      );
    });

    testWidgets('should say « 1 maison visitée », « 1 don » and « 2 '
        'calendriers offerts »', (tester) async {
      await pumpRecap(
        tester,
        round: Round.restore(
          id: roundId,
          sector: sector49Id,
          campaign: year2026,
          startedAt: _start,
          housesVisited: 1,
          donations: [offered, cash(500), offered],
        ),
      );

      expect(lineText(tester, 'recap.houses'), '1 | maison visitée');
      expect(lineText(tester, 'recap.dons'), '1 | don');
      expect(lineText(tester, 'recap.free'), '2 | calendriers offerts');
      expect(
        lineText(tester, 'recap.cheque'),
        'Chèques | 0${_nbsp}don | 0$_nbsp€',
      );
    });

    testWidgets('should end the tournée now, read when the « Bilan » opens', (
      tester,
    ) async {
      await pumpHome(tester, round: _round());
      clock.time = DateTime(2026, 10, 24, 19).toUtc();

      await tap(tester, _key('round.finish'));

      expect(
        _text(tester, 'recap.when'),
        'Samedi 24 octobre, de 14${_nbsp}h${_nbsp}05 à 19${_nbsp}h',
      );
    });

    testWidgets('should open the dons from « Voir les dons »', (tester) async {
      await pumpRecap(tester);

      await tap(tester, _key('recap.seeDons'));

      expect(find.byType(DonsScreen), findsOneWidget);
    });

    testWidgets('should go back, the tournée on, with « Continuer la '
        'tournée »', (tester) async {
      await pumpRecap(tester);

      await tap(tester, _key('recap.continue'));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_key('round.band'), findsOneWidget);
    });

    testWidgets('should ask before validating, and change nothing on '
        '« Annuler »', (tester) async {
      await pumpRecap(tester);

      await tap(tester, _key('recap.validate'));
      expect(find.text('Valider la tournée$_nbsp?'), findsOneWidget);
      expect(find.text('Vous ne pourrez plus la modifier.'), findsOneWidget);
      await tap(tester, _key('recap.confirm.cancel'));

      expect(find.byType(RoundRecapScreen), findsOneWidget);
      expect(rounds.openRound, isNotNull);
    });

    testWidgets('should validate the tournée and go back to Accueil without '
        'one', (tester) async {
      await pumpRecap(tester);

      await tap(tester, _key('recap.validate'));
      await tap(tester, _key('recap.confirm.ok'));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(rounds.openRound, isNull);
      expect(_key('round.band'), findsNothing);
      expect(_key('round.start'), findsOneWidget);
      expect(_key('home.settings'), findsOneWidget);
    });

    testWidgets('should offer « Abandonner la tournée » in red under '
        '« Continuer la tournée »', (tester) async {
      await pumpRecap(tester);

      final abandon = tester.widget<TextButton>(_key('recap.abandon'));
      expect(
        find.descendant(
          of: _key('recap.abandon'),
          matching: find.text('Abandonner la tournée'),
        ),
        findsOneWidget,
      );
      expect(
        abandon.style!.foregroundColor!.resolve({}),
        AppColors.of(tester.element(_key('recap.abandon'))).accent,
      );
      expect(
        tester.getTopLeft(_key('recap.abandon')).dy,
        greaterThan(tester.getBottomLeft(_key('recap.continue')).dy),
      );
      expect(
        tester.getSize(_key('recap.abandon')).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('should ask before abandoning, and change nothing on '
        '« Annuler »', (tester) async {
      await pumpRecap(tester);

      await tap(tester, _key('recap.abandon'));
      expect(find.text('Abandonner la tournée$_nbsp?'), findsOneWidget);
      expect(
        find.text(
          'Ses dons seront perdus. Les maisons marquées restent marquées.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('recap.abandonConfirm.ok'),
          matching: find.text('Abandonner'),
        ),
        findsOneWidget,
      );
      await tap(tester, _key('recap.abandonConfirm.cancel'));

      expect(find.byType(RoundRecapScreen), findsOneWidget);
      expect(rounds.openRound, _round());
      expect(rounds.clears, 0);
    });

    testWidgets('should abandon the tournée and go back to Accueil with its '
        'top bar, nothing sent to the secteur', (tester) async {
      await pumpRecap(tester);

      await tap(tester, _key('recap.abandon'));
      await tap(tester, _key('recap.abandonConfirm.ok'));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(rounds.openRound, isNull);
      expect(ledger.recorded, isEmpty);
      expect(_key('round.band'), findsNothing);
      expect(_key('round.start'), findsOneWidget);
      expect(_key('home.settings'), findsOneWidget);
    });
  });
}
