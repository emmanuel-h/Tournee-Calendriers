import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/round/dons_screen.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/finders.dart';

// The don of the status picker during a tournée (PLAN §5.6, §5.13,
// RunStreet mockup): « Montant du don » after « Fait », « + Ajouter un
// don » on a house done, the snackbar and its « Annuler ».

const _nbsp = ' ';

final _id = StreetId('lilas');

/// 3 done, 5 nobody home twice, 7 to do; 8 a building, its RdC with two
/// doors to do.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('3'), status: VisitStatus.done),
      House(number: n('5'), status: VisitStatus.nobodyHome, tries: tries(2)),
      House(number: n('7')),
      House(number: n('8'), building: building(topFloor: 0, doors: 2)),
    ],
  ),
);

/// The 49's tournée with one don in it, 20 € by cheque.
Round _round() => Round.restore(
  id: roundId,
  sector: sector49Id,
  campaign: year2026,
  startedAt: startedAt,
  housesVisited: 4,
  donations: [cheque(2000)],
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));
Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  late FakeStreetRepository streets;
  late FakeOpenRoundStore rounds;

  /// The street screen of [_lilas] in the 49, open, with [round] on
  /// (the one of [_round] by default).
  Future<void> openStreet(WidgetTester tester, {bool roundOn = true}) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([_lilas]);
    rounds = FakeOpenRoundStore(roundOn ? _round() : null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          rounds: rounds,
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Taps [number], then « Fait » in its picker.
  Future<void> markDone(WidgetTester tester, String number) async {
    await tap(tester, _tile(number));
    await tap(tester, _key('house.status.done'));
  }

  House stored(String number) =>
      streets[_id]!.houses.singleWhere((house) => house.number == n(number));

  List<Donation> dons() => rounds.openRound!.donations;

  group('after « Fait »', () {
    testWidgets('should ask for the don, on Espèces, with « Fait » stored', (
      tester,
    ) async {
      await openStreet(tester);

      await markDone(tester, '7');

      expect(find.text('Montant du don'), findsOneWidget);
      expect(stored('7').status, VisitStatus.done);
      expect(
        tester
            .getSemantics(_key('house.method.cash'))
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      expect(find.text('5$_nbsp€'), findsOneWidget);
      expect(find.text('10$_nbsp€'), findsOneWidget);
      expect(find.text('20$_nbsp€'), findsOneWidget);
      expect(find.text('Autre montant'), findsOneWidget);
      expect(find.text('Calendrier offert'), findsOneWidget);
      expect(
        find.byTooltip('Annuler$_nbsp: la maison reprend son statut'),
        findsOneWidget,
      );
      // Nothing told yet: the snackbar waits for the don.
      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('should give 10 € in cash to the tournée and say it, the '
        'house done', (tester) async {
      await openStreet(tester);
      await markDone(tester, '7');

      await tap(tester, _key('house.give.1000'));

      expect(find.text('Montant du don'), findsNothing);
      expect(dons(), [cheque(2000), cash(1000)]);
      expect(stored('7').status, VisitStatus.done);
      expect(findArrowText('N° 7 fait · 10$_nbsp€ en espèces'), findsOneWidget);
      expect(rounds.openRound!.housesVisited, 5);
    });

    testWidgets('should give the method chosen', (tester) async {
      await openStreet(tester);
      await markDone(tester, '7');
      await tap(tester, _key('house.method.card'));

      await tap(tester, _key('house.give.500'));

      expect(dons().last, card(500));
      expect(findArrowText('N° 7 fait · 5$_nbsp€ en carte'), findsOneWidget);
    });

    testWidgets('should give a free calendar', (tester) async {
      await openStreet(tester);
      await markDone(tester, '7');

      await tap(tester, _key('house.freeCalendar'));

      expect(dons().last, offered);
      expect(findArrowText('N° 7 fait · calendrier offert'), findsOneWidget);
    });

    testWidgets('should put the house back and take the don out with '
        '« Annuler »', (tester) async {
      await openStreet(tester);
      await markDone(tester, '5');
      await tap(tester, _key('house.give.2000'));

      await tap(tester, find.text('Annuler'));

      expect(stored('5'), _lilas.houses[1]);
      expect(dons(), [cheque(2000)]);
      expect(rounds.openRound!.housesVisited, 4);
    });

    testWidgets('should put the house back as it was, and say nothing, '
        'when ✕ closes the step', (tester) async {
      await openStreet(tester);
      await markDone(tester, '5');

      await tap(tester, _key('house.close'));

      expect(find.text('Montant du don'), findsNothing);
      expect(stored('5'), _lilas.houses[1]);
      expect(dons(), [cheque(2000)]);
      expect(rounds.openRound!.housesVisited, 4);
      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('should put the house back when the street is tapped beside '
        'the step', (tester) async {
      await openStreet(tester);
      await markDone(tester, '7');

      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(stored('7').status, VisitStatus.toDo);
      expect(stored('7').lastChange, isNull);
    });

    testWidgets('should not ask for a don when no tournée is on', (
      tester,
    ) async {
      await openStreet(tester, roundOn: false);

      await markDone(tester, '7');

      expect(find.text('Montant du don'), findsNothing);
      expect(findArrowText('N° 7$_nbsp: fait'), findsOneWidget);
    });

    testWidgets('should not ask for a don when « Fait » is tapped on a house '
        'done', (tester) async {
      await openStreet(tester);

      await markDone(tester, '3');

      expect(find.text('Montant du don'), findsNothing);
      expect(dons(), [cheque(2000)]);
    });
  });

  group('« Autre montant »', () {
    /// « Fait » on 7, then « Autre montant ».
    Future<void> other(WidgetTester tester) async {
      await openStreet(tester);
      await markDone(tester, '7');
      await tap(tester, _key('house.otherAmount'));
    }

    Future<void> typeAndValidate(WidgetTester tester, String text) async {
      await tester.enterText(_key('house.amount'), text);
      await tap(tester, _key('house.giveTyped'));
    }

    testWidgets('should keep the method chosen before, and give the amount '
        'typed', (tester) async {
      await openStreet(tester);
      await markDone(tester, '7');
      await tap(tester, _key('house.method.cheque'));
      await tap(tester, _key('house.otherAmount'));

      expect(find.text('Par exemple 7,50'), findsOneWidget);
      expect(
        tester
            .getSemantics(_key('house.method.cheque'))
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      await typeAndValidate(tester, '7,5');

      expect(dons().last, cheque(750));
      expect(
        findArrowText('N° 7 fait · 7,50$_nbsp€ en chèque'),
        findsOneWidget,
      );
    });

    for (final (typed, refusal) in [
      ('', 'Écrivez un montant.'),
      ('0', 'Entrez un montant valide.'),
      ('dix', 'Entrez un montant valide.'),
      ('7,505', 'Deux chiffres après la virgule au plus.'),
      ('1000,01', '1${_nbsp}000$_nbsp€ au plus par don.'),
    ]) {
      testWidgets('should refuse « $typed » under « Montant », the step '
          'still open', (tester) async {
        await other(tester);

        await typeAndValidate(tester, typed);

        expect(find.text(refusal), findsOneWidget);
        expect(find.text('Par exemple 7,50'), findsNothing);
        expect(dons(), [cheque(2000)]);
        expect(stored('7').status, VisitStatus.done);
      });
    }

    testWidgets('should give the amount on the keyboard\'s « OK »', (
      tester,
    ) async {
      await other(tester);
      await tester.enterText(_key('house.amount'), '1000');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(dons().last, cash(100000));
    });

    testWidgets('should go back to « Montant du don » with the arrow', (
      tester,
    ) async {
      await other(tester);

      await tap(tester, _key('house.otherAmountBack'));

      expect(find.text('Montant du don'), findsOneWidget);
      expect(stored('7').status, VisitStatus.done);
    });

    testWidgets('should start without a refusal when opened again', (
      tester,
    ) async {
      await other(tester);
      await typeAndValidate(tester, '');
      await tap(tester, _key('house.otherAmountBack'));

      await tap(tester, _key('house.otherAmount'));

      expect(find.text('Écrivez un montant.'), findsNothing);
    });
  });

  group('« + Ajouter un don »', () {
    testWidgets('should show on a house done only', (tester) async {
      await openStreet(tester);
      await tap(tester, _tile('3'));
      expect(_key('house.addDonation'), findsOneWidget);
      await tap(tester, _key('house.close'));

      await tap(tester, _tile('5'));

      expect(_key('house.addDonation'), findsNothing);
    });

    testWidgets('should not show when no tournée is on', (tester) async {
      await openStreet(tester, roundOn: false);

      await tap(tester, _tile('3'));

      expect(_key('house.addDonation'), findsNothing);
    });

    testWidgets('should give a don to the tournée, the house as it was, and '
        'take it back with « Annuler »', (tester) async {
      await openStreet(tester);
      await tap(tester, _tile('3'));
      await tap(tester, _key('house.addDonation'));
      expect(find.byTooltip('Fermer'), findsOneWidget);
      await tap(tester, _key('house.method.cheque'));

      await tap(tester, _key('house.give.500'));

      expect(dons(), [cheque(2000), cheque(500)]);
      expect(stored('3'), _lilas.houses.first);
      expect(findArrowText('N° 3 · 5$_nbsp€ en chèque ajouté'), findsOneWidget);

      await tap(tester, find.text('Annuler'));

      expect(dons(), [cheque(2000)]);
      expect(stored('3'), _lilas.houses.first);
    });

    testWidgets('should only close on its ✕, the house still done', (
      tester,
    ) async {
      await openStreet(tester);
      await tap(tester, _tile('3'));
      await tap(tester, _key('house.addDonation'));

      await tap(tester, _key('house.close'));

      expect(find.text('Montant du don'), findsNothing);
      expect(stored('3'), _lilas.houses.first);
      expect(dons(), [cheque(2000)]);
      expect(find.text('Annuler'), findsNothing);
    });
  });

  group('the street screen', () {
    testWidgets('should show the tournée under the progress bar and open its '
        'dons', (tester) async {
      await openStreet(tester);

      expect(
        tester.widget<Text>(_key('round.line.totals')).data,
        'En tournée · 1${_nbsp}don · 20$_nbsp€',
      );
      final line = tester.getRect(_key('round.line'));
      expect(
        line.top,
        greaterThan(tester.getRect(_key('street.progress')).bottom),
      );
      expect(
        line.bottom,
        lessThan(tester.getTopLeft(find.text('CÔTÉ IMPAIR')).dy),
      );
      await tap(tester, _key('round.line'));

      expect(find.byType(DonsScreen), findsOneWidget);
    });

    testWidgets('should show no tournée line when none is on', (tester) async {
      await openStreet(tester, roundOn: false);

      expect(_key('round.line'), findsNothing);
    });

    testWidgets('should drop the snackbar when the dons open, so its '
        '« Annuler » takes no other don back', (tester) async {
      await openStreet(tester);
      await markDone(tester, '7');
      await tap(tester, _key('house.give.1000'));

      await tap(tester, _key('round.line'));
      await tap(tester, find.byTooltip('Retour'));

      expect(find.text('Annuler'), findsNothing);
    });
  });

  testWidgets('should ask for the don of a door made « Fait », and say it', (
    tester,
  ) async {
    await openStreet(tester);
    await tap(tester, _tile('8'));
    await tap(tester, _key('grid.door.A0-01'));
    await tap(tester, _key('door.status.done'));
    expect(
      find.byTooltip('Annuler$_nbsp: la porte reprend son statut'),
      findsOneWidget,
    );

    await tap(tester, _key('door.give.1000'));

    expect(dons().last, cash(1000));
    expect(
      findArrowText('Porte 01$_nbsp: fait · 10$_nbsp€ en espèces'),
      findsOneWidget,
    );
    final door = stored('8').building!
        .dwellingAt(DwellingKey(escA, 0, d('01')));
    expect(door!.status, VisitStatus.done);
  });

  testWidgets('should give a don to a door done, and say it', (tester) async {
    await openStreet(tester);
    await tap(tester, _tile('8'));
    await tap(tester, _key('grid.door.A0-02'));
    await tap(tester, _key('door.status.done'));
    await tap(tester, _key('door.give.500'));
    await tap(tester, _key('grid.door.A0-02'));

    await tap(tester, _key('door.addDonation'));
    await tap(tester, _key('door.freeCalendar'));

    expect(dons(), [cheque(2000), cash(500), offered]);
    expect(
      findArrowText('Porte 02 · calendrier offert ajouté'),
      findsOneWidget,
    );
  });
}
