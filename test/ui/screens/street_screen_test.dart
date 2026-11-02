import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/components/building_icon.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/finders.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

final _id = StreetId('lilas');

/// The Main mockup in short: 1 to do, 3 done, 3bis nobody home, 5 to come
/// back, 7 to do; 2 done, 4 to do, 8 a building with 1 of its 2
/// doors done.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(number: n('3'), status: VisitStatus.done),
      House(number: n('3bis'), status: VisitStatus.nobodyHome),
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07', hour: 19),
      ),
      House(number: n('7')),
      House(number: n('2'), status: VisitStatus.done),
      House(number: n('4')),
      House(
        number: n('8'),
        building: building(topFloor: 0, doors: 2).withDwelling(
          escA,
          0,
          Dwelling(label: d('01'), status: VisitStatus.done),
        ),
      ),
    ],
  ),
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));

void main() {
  late FakeStreetRepository streets;
  late FakeStreetViewPreferences preferences;

  /// Starts the app on « Mes rues » with [street] on the phone, then opens
  /// [location] (the street screen of [street] by default), as the start
  /// list does.
  Future<void> openStreet(
    WidgetTester tester, {
    Street? street,
    String? location,
  }) async {
    streets = FakeStreetRepository([street ?? _lilas]);
    preferences = FakeStreetViewPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: streets, preferences: preferences),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaitedPush(router, location ?? AppRoutes.streetOf(_id));
    await tester.pumpAndSettle();
  }

  String labelOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).label;

  /// Taps the tile of [number], then [status] in its picker.
  Future<void> mark(
    WidgetTester tester,
    String number,
    VisitStatus status,
  ) async {
    await tester.tap(_tile(number));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('house.status.${status.name}')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'should say to tap a house, open its picker on a tap, and count what it '
    'stores',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('street.hint')),
          matching: find.text('Appuyez sur une maison pour changer son statut'),
        ),
        findsOneWidget,
      );

      await tester.tap(_tile('1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('house.number')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('house.status.done')));
      await tester.pumpAndSettle();

      expect(labelOf(tester, _tile('1')), 'Numéro 1, fait, changer le statut');
      expect(findArrowText('N° 1\u00a0: fait'), findsOneWidget);
      expect(find.byKey(const Key('street.hint')), findsNothing);
      expect(
        labelOf(tester, find.byKey(const Key('street.counts'))),
        '4 sur 9 faits, 1 personne, 1 à repasser',
      );

      // The next house: the snackbar of the first goes as its picker opens.
      await tester.tap(_tile('7'));
      await tester.pumpAndSettle();
      expect(findArrowText('N° 1\u00a0: fait'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('house.status.nobodyHome')));
      await tester.pumpAndSettle();

      expect(findArrowText('N° 7\u00a0: personne'), findsOneWidget);
      expect(
        labelOf(tester, find.byKey(const Key('street.counts'))),
        '4 sur 9 faits, 2 personne, 1 à repasser',
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should show a building icon, a « › » and « ouvrir » on a building tile '
    'only',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);

      expect(
        labelOf(tester, _tile('8')),
        'Numéro 8, immeuble, 1 sur 2 faits, ouvrir',
      );
      for (final type in [BuildingIcon, OpenChevron]) {
        expect(
          find.descendant(of: _tile('8'), matching: find.byType(type)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _tile('4'), matching: find.byType(type)),
          findsNothing,
        );
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'should put the house back and the hint again when Annuler is tapped',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await mark(tester, '5', VisitStatus.toDo);
      expect(
        labelOf(tester, _tile('5')),
        'Numéro 5, à faire, changer le statut',
      );

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(
        labelOf(tester, _tile('5')),
        'Numéro 5, repasser, changer le statut',
      );
      expect(streets[_id]!.houses, _lilas.houses);
      expect(findArrowText('N° 5\u00a0: à faire'), findsNothing);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'should leave the snackbar after 4 s and keep the mark when not undone',
    (tester) async {
      await openStreet(tester);
      await mark(tester, '4', VisitStatus.done);
      expect(findArrowText('N° 4\u00a0: fait'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(findArrowText('N° 4\u00a0: fait'), findsNothing);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
      expect(
        streets[_id]!.houses.singleWhere((h) => h.number == n('4')).status,
        VisitStatus.done,
      );
    },
  );

  testWidgets(
    'should hide the done tiles and remember it when Masquer faits is on',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      final toggle = find.byKey(const Key('street.hideDone'));
      expect(
        tester.getSemantics(toggle).flagsCollection.isToggled.toBoolOrNull(),
        false,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(_tile('3'), findsNothing);
      expect(_tile('2'), findsNothing);
      expect(_tile('1'), findsOneWidget);
      expect(_tile('3bis'), findsOneWidget);
      expect(_tile('8'), findsOneWidget);
      // The counts still cover the whole street.
      expect(
        labelOf(tester, find.byKey(const Key('street.counts'))),
        '3 sur 9 faits, 1 personne, 1 à repasser',
      );
      expect(
        tester.getSemantics(toggle).flagsCollection.isToggled.toBoolOrNull(),
        true,
      );
      expect(preferences.writes, [(_id, true)]);
      semantics.dispose();
    },
  );

  testWidgets(
    'should show a single wide column when the street has one side only',
    (tester) async {
      await openStreet(
        tester,
        street: valueOf(
          Street.create(
            id: _id,
            name: 'Impasse des Lilas',
            commune: villefranche,
            houses: [
              House(number: n('1')),
              House(number: n('3')),
            ],
          ),
        ),
      );

      expect(find.text('CÔTÉ IMPAIR'), findsOneWidget);
      expect(find.text('CÔTÉ PAIR'), findsNothing);
      final screen = tester.getSize(find.byType(Scaffold).last);
      expect(tester.getSize(_tile('1')).width, screen.width - 2 * 16);
      expect(
        tester.getTopLeft(_tile('3')).dy,
        tester.getTopLeft(_tile('1')).dy + 70,
      );
    },
  );

  testWidgets('should say the street is gone when it is not on the phone', (
    tester,
  ) async {
    await openStreet(tester, location: AppRoutes.streetOf(StreetId('autre')));

    expect(find.text("Cette rue n'est plus sur ce téléphone."), findsOneWidget);
    expect(find.byKey(const Key('street.edit')), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    // A link naming no street says the same.
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));
    unawaitedPush(router, AppRoutes.street);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Rue'), findsOneWidget);
    expect(find.text("Cette rue n'est plus sur ce téléphone."), findsOneWidget);
  });

  testWidgets('should open the edit mode of the street when ✏ is tapped', (
    tester,
  ) async {
    await openStreet(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));

    await tester.tap(find.byKey(const Key('street.edit')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Modifier la rue'), findsOneWidget);
    expect(router.state.uri.toString(), AppRoutes.editStreetOf(_id));
  });

  group('counts row with the app fonts (#35)', () {
    setUpAll(loadAppFonts);

    final counts = find.byKey(const Key('street.counts'));
    final hideDone = find.byKey(const Key('street.hideDone'));

    /// Whether the counts had to be cut with « … ».
    bool countsCut(WidgetTester tester) => tester
        .renderObject<RenderParagraph>(
          find.descendant(of: counts, matching: find.byType(RichText)),
        )
        .didExceedMaxLines;

    testWidgets('should put the counts and « Masquer faits » on one row when '
        'the text is at its normal size', (tester) async {
      usePhoneScreen(tester);

      await openStreet(tester);

      final countsBox = tester.getRect(counts);
      final pillBox = tester.getRect(hideDone);
      expect(pillBox.center.dy, moreOrLessEquals(countsBox.center.dy));
      expect(pillBox.left, greaterThanOrEqualTo(countsBox.right));
      // As before #35: the pill at the right edge, the counts at the left.
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(pillBox.right, moreOrLessEquals(screenWidth - AppSizes.gutter));
      expect(countsBox.left, AppSizes.streetCountsIndent);
      expect(countsCut(tester), isFalse);
    });

    testWidgets('should put « Masquer faits » under the whole counts when the '
        'text is twice as large', (tester) async {
      useLargeText(tester);

      await openStreet(tester);

      final countsBox = tester.getRect(counts);
      final pillBox = tester.getRect(hideDone);
      expect(pillBox.top, greaterThanOrEqualTo(countsBox.bottom));
      expect(pillBox.left, countsBox.left);
      expect(countsCut(tester), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    testWidgets('should show the street with no overflow when the text is '
        'twice as large', (tester) async {
      useLargeText(tester);

      await openStreet(tester);

      // The header, the hint and the first tiles, all on screen and whole
      // (an overflow would have thrown).
      expect(find.text('Rue des Lilas'), findsWidgets);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
      expect(_tile('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('should say the status of a tile when the text is twice as '
        'large', (tester) async {
      final semantics = tester.ensureSemantics();
      useLargeText(tester);
      await openStreet(tester);

      await mark(tester, '1', VisitStatus.done);

      expect(labelOf(tester, _tile('1')), 'Numéro 1, fait, changer le statut');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await openStreet(tester);

    await expectAccessibleControls(tester);
  });
}
