import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/building_grid_sheet.dart';
import 'package:tournee_calendriers/ui/screens/round/dons_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/round_recap_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/large_text.dart';

// The « En tournée » band (PLAN §5.14, mockups RunHome and RunStreet): in
// Accueil's top bar's place, above the street screen's top bar and the
// building grid's header; Surface with an Accent edge in both themes;
// heard by TalkBack; whole at 200 % text. Accueil's own cases (no secteur
// switch, no Secteur, no ⚙) are in `round_screens_test.dart`.

const _nbsp = '\u00a0';

final _id = StreetId('lilas');

/// 7 a house to do; 8 a building, its RdC with two doors to do.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('7')),
      House(number: n('8'), building: building(topFloor: 0, doors: 2)),
    ],
  ),
);

/// The 49's tournée, started 1 h 20 before [_now], with one don of 20 € by
/// cheque.
Round _round() => Round.restore(
  id: roundId,
  sector: sector49Id,
  campaign: year2026,
  startedAt: startedAt,
  housesVisited: 4,
  donations: [cheque(2000)],
);

final _now = startedAt.add(const Duration(hours: 1, minutes: 20));

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  late FakeOpenRoundStore rounds;

  /// Accueil of the 49, with [_round] on unless [roundOn] is false, in the
  /// light theme unless [theme] says otherwise; a 411 × 914 dp phone.
  Future<void> pumpHome(
    WidgetTester tester, {
    bool roundOn = true,
    ThemeChoice theme = ThemeChoice.light,
  }) async {
    usePhoneScreen(tester);
    rounds = FakeOpenRoundStore(roundOn ? _round() : null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: FakeStreetRepository([_lilas]),
          rounds: rounds,
          clock: FakeClock(_now),
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
          settings: FakePhoneSettings(theme: theme),
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

  /// [pumpHome], then the street screen of [_lilas] pushed over Accueil.
  Future<void> openStreet(WidgetTester tester, {bool roundOn = true}) async {
    await pumpHome(tester, roundOn: roundOn);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
  }

  /// [openStreet], then the grid of the building 8.
  Future<void> openGrid(WidgetTester tester, {bool roundOn = true}) async {
    await openStreet(tester, roundOn: roundOn);
    await tap(tester, _key('street.tile.8'));
  }

  /// The band shown last: the grid's lies over the street screen's.
  Finder band(String key) => _key(key).last;

  group('the street screen', () {
    testWidgets('should show the band above its top bar during a tournée', (
      tester,
    ) async {
      await openStreet(tester);

      final appBar = find.widgetWithText(AppBar, 'Rue des Lilas');
      expect(appBar, findsOneWidget);
      expect(tester.getRect(band('round.band')).top, 0);
      expect(
        tester.getRect(band('round.band')).bottom,
        lessThanOrEqualTo(tester.getRect(appBar).top),
      );
      expect(
        tester.widget<Text>(band('round.band.since')).data,
        'En tournée · 1${_nbsp}h${_nbsp}20',
      );
      expect(
        tester.widget<Text>(band('round.band.totals')).data,
        '1${_nbsp}don · 20$_nbsp€ ›',
      );
      // The top bar leaves the status bar to the band.
      expect(tester.widget<AppBar>(appBar).primary, isFalse);
    });

    testWidgets('should show no band, and its top bar under the status bar, '
        'when none is on', (tester) async {
      await openStreet(tester, roundOn: false);

      expect(_key('round.band'), findsNothing);
      final appBar = find.widgetWithText(AppBar, 'Rue des Lilas');
      expect(tester.widget<AppBar>(appBar).primary, isTrue);
    });

    testWidgets('should open « Dons de la tournée » from the band', (
      tester,
    ) async {
      await openStreet(tester);

      await tap(tester, band('round.band.dons'));

      expect(find.byType(DonsScreen), findsOneWidget);
    });

    testWidgets('should open the « Bilan » from « Terminer »', (tester) async {
      await openStreet(tester);

      await tap(tester, band('round.finish'));

      expect(find.byType(RoundRecapScreen), findsOneWidget);
    });

    testWidgets('should drop the snackbar when the dons open, so its '
        '« Annuler » takes no other don back', (tester) async {
      await openStreet(tester);
      await tap(tester, _key('street.tile.7'));
      await tap(tester, _key('house.status.done'));
      await tap(tester, _key('house.give.1000'));
      expect(find.text('Annuler'), findsOneWidget);

      await tap(tester, band('round.band.dons'));
      await tap(tester, find.byTooltip('Retour'));

      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('should drop the snackbar when the « Bilan » opens', (
      tester,
    ) async {
      await openStreet(tester);
      await tap(tester, _key('street.tile.7'));
      await tap(tester, _key('house.status.done'));
      await tap(tester, _key('house.give.1000'));

      await tap(tester, band('round.finish'));
      await tap(tester, _key('recap.continue'));

      expect(find.text('Annuler'), findsNothing);
      expect(rounds.openRound!.donations, [cheque(2000), cash(1000)]);
    });
  });

  group('the building grid', () {
    testWidgets('should show the band above its header during a tournée', (
      tester,
    ) async {
      await openGrid(tester);

      // The street's and the grid's (Accueil, under an opaque page, is
      // offstage).
      expect(_key('round.band'), findsNWidgets(2));
      expect(
        tester.getRect(band('round.band')).bottom,
        lessThan(tester.getRect(_key('grid.close')).top),
      );
      // Under the grabber, inside the sheet.
      expect(
        tester.getRect(band('round.band')).top,
        greaterThan(tester.getRect(find.byType(BuildingGridSheet)).top),
      );
    });

    testWidgets('should show no band when none is on', (tester) async {
      await openGrid(tester, roundOn: false);

      expect(_key('grid.close'), findsOneWidget);
      expect(_key('round.band'), findsNothing);
    });

    testWidgets('should drop the snackbar of a door when the dons open', (
      tester,
    ) async {
      await openGrid(tester);
      await tap(tester, _key('grid.door.A0-01'));
      await tap(tester, _key('door.status.done'));
      await tap(tester, _key('door.give.1000'));
      expect(find.text('Annuler'), findsOneWidget);

      await tap(tester, band('round.band.dons'));
      expect(find.byType(DonsScreen), findsOneWidget);
      await tap(tester, find.byTooltip('Retour'));

      expect(_key('grid.close'), findsOneWidget);
      expect(find.text('Annuler'), findsNothing);
    });
  });

  group('colours', () {
    /// The band's background, its left edge and the line under it.
    ({Color background, BorderSide edge, BorderSide under}) looks(
      WidgetTester tester,
    ) {
      final material = tester.widget<Material>(_key('round.band'));
      final border =
          (tester.widget<DecoratedBox>(_key('round.band.edge')).decoration
                      as BoxDecoration)
                  .border!
              as Border;
      return (
        background: material.color!,
        edge: border.left,
        under: border.bottom,
      );
    }

    SystemUiOverlayStyle statusBar(WidgetTester tester) => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find
              .ancestor(
                of: _key('round.band'),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              )
              .first,
        )
        .value;

    testWidgets('should be Surface with a 6 dp Accent edge and the divider '
        'under it, dark status bar icons, in the light theme', (tester) async {
      await pumpHome(tester);

      final band = looks(tester);
      expect(band.background, AppColors.light.surface);
      expect(band.edge.color, AppColors.light.accent);
      expect(band.edge.width, 6);
      expect(band.under.color, AppColors.light.divider);
      expect(band.under.width, 1);
      expect(statusBar(tester).statusBarIconBrightness, Brightness.dark);
      final finish = tester.widget<FilledButton>(_key('round.finish'));
      final states = <WidgetState>{};
      expect(
        finish.style!.backgroundColor!.resolve(states),
        AppColors.light.ink,
      );
      expect(
        finish.style!.foregroundColor!.resolve(states),
        AppColors.light.surface,
      );
    });

    testWidgets('should take the dark Surface and Accent, light status bar '
        'icons, in the dark theme', (tester) async {
      await pumpHome(tester, theme: ThemeChoice.dark);

      final band = looks(tester);
      expect(band.background, AppColors.dark.surface);
      expect(band.edge.color, AppColors.dark.accent);
      expect(band.under.color, AppColors.dark.divider);
      expect(statusBar(tester).statusBarIconBrightness, Brightness.light);
      final finish = tester.widget<FilledButton>(_key('round.finish'));
      final states = <WidgetState>{};
      expect(
        finish.style!.backgroundColor!.resolve(states),
        AppColors.dark.ink,
      );
      expect(
        finish.style!.foregroundColor!.resolve(states),
        AppColors.dark.surface,
      );
    });
  });

  group('TalkBack', () {
    testWidgets('should read the left part as one button, then « Terminer la '
        'tournée », each 48 dp at least', (tester) async {
      await pumpHome(tester);
      final semantics = tester.ensureSemantics();

      expect(
        tester.getSemantics(_key('round.band.dons')),
        isSemantics(
          label:
              'En tournée depuis 1${_nbsp}h${_nbsp}20, 1${_nbsp}don, '
              '20$_nbsp€. Voir les dons',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(_key('round.finish')),
        isSemantics(
          label: 'Terminer la tournée',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSize(_key('round.band.dons')).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.getSize(_key('round.finish')).height, 48);
      semantics.dispose();
      await expectAccessibleControls(tester);
    });
  });

  // Last of the file: the real fonts stay loaded for every test after it.
  group('200 % text', () {
    setUpAll(loadAppFonts);

    testWidgets('should wrap the band\'s lines on Accueil and keep '
        '« Terminer » whole', (tester) async {
      await pumpHome(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();

      // One line of « Terminer »: 15 dp at 200 %, under two lines' height.
      expect(tester.getSize(find.text('Terminer')).height, lessThan(60));
      expect(
        tester.getRect(_key('round.finish')).right,
        lessThanOrEqualTo(tester.getSize(find.byType(TourneeApp)).width),
      );
      // « En tournée · 1 h 20 » no longer fits beside it: it wraps.
      expect(tester.getSize(_key('round.band.since')).height, greaterThan(60));
      await expectAccessibleControls(tester);
    });

    testWidgets('should hold the band above the street\'s top bar', (
      tester,
    ) async {
      await openStreet(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(band('round.band')).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.widgetWithText(AppBar, 'Rue des Lilas')).top,
        ),
      );
      expect(tester.getSize(find.text('Terminer').last).height, lessThan(60));
    });
  });
}
