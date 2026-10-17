import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/finders.dart';

final _id = StreetId('lilas');

/// 1 to do, 5 « repasser » Saturday 7 at 19 h, 7 to do, 9 nobody home
/// twice, 11 « repasser » yesterday at 19 h (today is Monday 2 November).
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07', hour: 19),
      ),
      House(number: n('7')),
      House(number: n('9'), status: VisitStatus.nobodyHome, tries: tries(2)),
      House(
        number: n('11'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-01', hour: 19),
      ),
    ],
  ),
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));

void main() {
  late FakeStreetRepository streets;

  /// Opens the street screen of [_lilas].
  Future<void> openStreet(WidgetTester tester) async {
    // A phone-sized screen (411 × 914 dp): on the default 800 × 600 test
    // surface the sheet reaches the top, leaving no dimmed street to tap.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([_lilas]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: streets),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
  }

  /// Opens the street screen of [_lilas], then holds the tile of [number].
  Future<void> holdTile(WidgetTester tester, String number) async {
    await openStreet(tester);
    await tester.longPress(_tile(number));
    await tester.pumpAndSettle();
  }

  /// Taps the dimmed street above the sheet, which closes it.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
  }

  Finder dayChip(String iso) => find.byKey(ValueKey('house.comeBackDay.$iso'));

  String? summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('house.comeBackSummary'))).data;

  /// Scrolls the row of days to the chip of [iso], then taps it.
  Future<void> tapDay(WidgetTester tester, String iso) async {
    await tester.ensureVisible(dayChip(iso));
    await tester.pumpAndSettle();
    await tester.tap(dayChip(iso));
  }

  /// Opens the hour list of the sheet and picks [label] (« 18 h »).
  Future<void> chooseHour(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('house.comeBackHour')));
    await tester.pumpAndSettle();
    // The open list shows its items over the sheet; the last one found is
    // in the list, the first is the one shown in the closed field.
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  House stored(String number) =>
      streets[_id]!.houses.singleWhere((house) => house.number == n(number));

  SemanticsData semanticsOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  testWidgets(
    'should show ↻ on the tile when Repasser is chosen in the held house '
    'sheet, then store the day and hour chosen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await holdTile(tester, '1');
      expect(find.byKey(const Key('house.number')), findsOneWidget);
      expect(find.text('Rue des Lilas'), findsWidgets);
      // No free note: too sensitive to keep about people (PLAN §8.3).
      expect(find.byKey(const Key('house.note.field')), findsNothing);
      expect(find.textContaining('Note'), findsNothing);
      expect(find.textContaining("N'écrivez"), findsNothing);
      expect(find.byKey(const Key('house.lastChange')), findsNothing);
      // Held, not tapped: no « Annuler » / « OK ».
      expect(find.byKey(const Key('house.ok')), findsNothing);
      expect(find.byKey(const Key('house.cancelTap')), findsNothing);
      expect(find.text('Quand repasser ?'), findsOneWidget);
      expect(summary(tester), 'Pas de jour choisi');
      // Greyed: the days answer nothing.
      await tapDay(tester, '2026-11-03');
      await tester.pumpAndSettle();
      expect(streets.saved, isEmpty);

      await tester.tap(find.byKey(const ValueKey('house.status.comeBack')));
      await tester.pumpAndSettle();

      expect(
        semanticsOf(
          tester,
          find.byKey(const ValueKey('house.status.comeBack')),
        ).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      await tapDay(tester, '2026-11-03');
      await tester.pumpAndSettle();
      expect(summary(tester), 'Demain');
      expect(
        semanticsOf(tester, dayChip('2026-11-03')).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      await chooseHour(tester, '18 h');
      expect(summary(tester), 'Demain vers 18 h');
      await closeSheet(tester);

      expect(find.byKey(const Key('house.number')), findsNothing);
      expect(tester.getSemantics(_tile('1')).label, 'Numéro 1, repasser');
      expect(stored('1').status, VisitStatus.comeBack);
      expect(stored('1').comeBack, comeBack('2026-11-03', hour: 18));
      semantics.dispose();
    },
  );

  testWidgets(
    'should offer a week of days from today, the dated ones read in full',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await holdTile(tester, '5');

      // Monday 2 November 2026 is today (the fake clock).
      for (final (iso, label) in [
        ('2026-11-02', "Aujourd'hui"),
        ('2026-11-03', 'Demain'),
        ('2026-11-04', 'Mer. 4'),
        ('2026-11-08', 'Dim. 8'),
      ]) {
        expect(
          find.descendant(of: dayChip(iso), matching: find.text(label)),
          findsOneWidget,
          reason: iso,
        );
      }
      expect(dayChip('2026-11-09'), findsNothing);
      expect(
        semanticsOf(tester, dayChip('2026-11-07')).label,
        'samedi 7 novembre',
      );
      expect(summary(tester), 'Le samedi 7 nov. vers 19 h');
      semantics.dispose();
    },
  );

  testWidgets(
    'should grey « Quand repasser ? » and drop its time when Fait is chosen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await holdTile(tester, '5');
      expect(summary(tester), 'Le samedi 7 nov. vers 19 h');

      await tester.tap(find.byKey(const ValueKey('house.status.done')));
      await tester.pumpAndSettle();

      expect(summary(tester), 'Pas de jour choisi');
      expect(
        semanticsOf(
          tester,
          find.byKey(const ValueKey('house.status.done')),
        ).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      final local = twoPm.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      expect(
        find.text('Modifié par vous · ${two(local.hour)}:${two(local.minute)}'),
        findsOneWidget,
      );
      expect(stored('5').status, VisitStatus.done);
      expect(stored('5').comeBack, isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'should keep the sheet and its blocks in place whichever of the four '
    'statuses is chosen',
    (tester) async {
      await holdTile(tester, '1');
      // The house was never changed: the first choice stamps it, and the
      // line « Modifié à … » appears in a place kept for it.
      Rect sheet() => tester.getRect(find.byType(BottomSheet));
      Rect time() =>
          tester.getRect(find.byKey(const Key('house.comeBackBlock')));
      Rect action() =>
          tester.getRect(find.byKey(const Key('house.toBuilding')));
      final before = (sheet(), time(), action());

      for (final status in [
        VisitStatus.done,
        VisitStatus.nobodyHome,
        VisitStatus.comeBack,
        VisitStatus.toDo,
      ]) {
        await tester.tap(find.byKey(ValueKey('house.status.${status.name}')));
        await tester.pumpAndSettle();

        expect(stored('1').status, status);
        expect((sheet(), time(), action()), before, reason: '$status');
      }
    },
  );

  testWidgets(
    'should leave no time when the chosen day is tapped again, and keep the '
    'day with « Pas d\'heure »',
    (tester) async {
      await holdTile(tester, '5');

      await chooseHour(tester, "Pas d'heure");
      expect(summary(tester), 'Le samedi 7 nov.');
      expect(stored('5').comeBack, comeBack('2026-11-07'));

      await tapDay(tester, '2026-11-07');
      await tester.pumpAndSettle();

      expect(summary(tester), 'Pas de jour choisi');
      expect(stored('5').status, VisitStatus.comeBack);
      expect(stored('5').comeBack, ComeBack.withoutTime);
    },
  );

  testWidgets('should say a day gone by is past, with a chip of its own', (
    tester,
  ) async {
    await holdTile(tester, '11');

    expect(summary(tester), "C'était hier vers 19 h");
    expect(
      find.descendant(of: dayChip('2026-11-01'), matching: find.text('Hier')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(dayChip('2026-11-01')).dx,
      lessThan(tester.getTopLeft(dayChip('2026-11-02')).dx),
    );
  });

  testWidgets(
    'should mark the house nobody home once more from its sheet, then put it '
    'back with Annuler',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await holdTile(tester, '9');
      expect(
        tester.widget<Text>(find.byKey(const Key('house.tries'))).data,
        '2 passages sans personne',
      );

      await tester.tap(find.byKey(const Key('house.nobodyHomeAgain')));
      await tester.pumpAndSettle();

      // The sheet closed; the street tells what changed, as after a tap.
      expect(find.byKey(const Key('house.number')), findsNothing);
      expect(stored('9').status, VisitStatus.nobodyHome);
      expect(stored('9').tries, tries(3));
      expect(findArrowText('9 → Personne (3e passage)'), findsOneWidget);
      expect(
        find.descendant(of: _tile('9'), matching: find.text('×3')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_tile('9')).label,
        'Numéro 9, personne, 3e passage',
      );

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(stored('9').tries, tries(2));
      expect(
        find.descendant(of: _tile('9'), matching: find.text('×2')),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should store the day before « Repassé, toujours personne » marks the '
    'house',
    (tester) async {
      await holdTile(tester, '5');
      // Its first try: the block counts none yet.
      expect(
        tester.widget<Text>(find.byKey(const Key('house.tries'))).data,
        '0 passage sans personne',
      );
      await tapDay(tester, '2026-11-04');

      await tester.tap(find.byKey(const Key('house.nobodyHomeAgain')));
      await tester.pumpAndSettle();

      expect(stored('5').status, VisitStatus.nobodyHome);
      expect(stored('5').tries, tries(1));
      // The day was stored first, then dropped with « repasser »: Annuler
      // gives the house back with it.
      expect(findArrowText('5 → Personne'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(stored('5').comeBack, comeBack('2026-11-04', hour: 19));
    },
  );

  testWidgets(
    'should grey « Repassé, toujours personne » while the house is not '
    'nobody home or to come back',
    (tester) async {
      await holdTile(tester, '1');
      final again = find.byKey(const Key('house.nobodyHomeAgain'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(of: again, matching: find.byType(OutlinedButton)),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('house.status.nobodyHome')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(of: again, matching: find.byType(OutlinedButton)),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('house.tries'))).data,
        '1 passage sans personne',
      );
    },
  );

  group('opened by a tap to ↻', () {
    testWidgets(
      'should open the sheet when a tap brings the house to ↻, without the '
      'snackbar, and store the day chosen',
      (tester) async {
        await openStreet(tester);

        await tester.tap(_tile('9'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('house.number')), findsOneWidget);
        expect(stored('9').status, VisitStatus.comeBack);
        expect(find.byKey(const Key('house.ok')), findsOneWidget);
        expect(find.byKey(const Key('house.cancelTap')), findsOneWidget);
        // The time is what it opened for: no « Transformer en immeuble… ».
        expect(find.byKey(const Key('house.toBuilding')), findsNothing);
        // The tries stay, enabled on ↻.
        expect(find.byKey(const Key('house.nobodyHomeAgain')), findsOneWidget);
        expect(findArrowText('9 → Repasser'), findsNothing);

        await tapDay(tester, '2026-11-03');
        await tester.pumpAndSettle();
        await chooseHour(tester, '20 h');
        await tester.tap(find.byKey(const Key('house.ok')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('house.number')), findsNothing);
        expect(findArrowText('9 → Repasser'), findsNothing);
        expect(stored('9').status, VisitStatus.comeBack);
        expect(stored('9').comeBack, comeBack('2026-11-03', hour: 20));
        expect(stored('9').tries, tries(2));
      },
    );

    testWidgets(
      'should put the house back as before the tap with Annuler, the day '
      'chosen with it',
      (tester) async {
        await openStreet(tester);
        await tester.tap(_tile('9'));
        await tester.pumpAndSettle();
        await tapDay(tester, '2026-11-04');

        await tester.tap(find.byKey(const Key('house.cancelTap')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('house.number')), findsNothing);
        expect(stored('9').status, VisitStatus.nobodyHome);
        expect(stored('9').comeBack, isNull);
        expect(stored('9').tries, tries(2));
        // Nothing left to undo: no snackbar.
        expect(find.text('Annuler'), findsNothing);
      },
    );

    testWidgets('should keep ↻ when the sheet is closed another way', (
      tester,
    ) async {
      await openStreet(tester);
      await tester.tap(_tile('9'));
      await tester.pumpAndSettle();

      await closeSheet(tester);

      expect(find.byKey(const Key('house.number')), findsNothing);
      expect(stored('9').status, VisitStatus.comeBack);
      expect(stored('9').comeBack, ComeBack.withoutTime);
    });

    testWidgets('should not open the sheet on a tap to another status', (
      tester,
    ) async {
      await openStreet(tester);

      await tester.tap(_tile('1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('house.number')), findsNothing);
      expect(stored('1').status, VisitStatus.done);
      expect(findArrowText('1 → Fait'), findsOneWidget);
    });
  });
}
