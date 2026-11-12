import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
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
import '../support/large_text.dart';

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

Finder _status(VisitStatus status) =>
    find.byKey(ValueKey('house.status.${status.name}'));

final _picker = find.byKey(const Key('house.number'));

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
        overrides: fakePhoneInRound(streets: streets),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
  }

  /// Opens the street screen, then taps the tile of [number]: its picker.
  Future<void> pick(WidgetTester tester, String number) async {
    await openStreet(tester);
    await tester.tap(_tile(number));
    await tester.pumpAndSettle();
  }

  /// Taps [status] in the picker that shows.
  Future<void> choose(WidgetTester tester, VisitStatus status) async {
    await tester.tap(_status(status));
    await tester.pumpAndSettle();
  }

  /// Taps the dimmed street above the sheet, which closes it.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
  }

  Finder dayChip(String iso) => find.byKey(ValueKey('house.comeBackDay.$iso'));
  final otherDay = find.byKey(const Key('house.comeBackOtherDay'));

  /// Taps [text] in the open calendar: a day (« 15 »), « OK » or
  /// « Annuler ».
  Future<void> tapInCalendar(WidgetTester tester, String text) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text(text),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? summary(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('house.comeBackSummary'))).data;

  /// Scrolls the row of days to the chip of [iso], then taps it.
  Future<void> tapDay(WidgetTester tester, String iso) async {
    await tester.ensureVisible(dayChip(iso));
    await tester.pumpAndSettle();
    await tester.tap(dayChip(iso));
    await tester.pumpAndSettle();
  }

  /// Opens the hour list and picks [label] (« 18 h »).
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

  List<String> announcements(WidgetTester tester) => [
    for (final announcement in tester.takeAnnouncements()) announcement.message,
  ];

  testWidgets(
    'should show the number, its status in grey and the five statuses two '
    'by two, the current one checked and the tile outlined, when a house is '
    'tapped',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      await openStreet(tester);
      expect(
        tester.getSemantics(_tile('7')).label,
        'Numéro 7, à faire, changer le statut',
      );

      await tester.tap(_tile('7'));
      await tester.pumpAndSettle();

      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(tester.widget<Text>(_picker).data, 'N° 7');
      expect(
        tester.widget<Text>(find.byKey(const Key('house.current'))).data,
        'À faire',
      );
      for (final status in VisitStatus.values) {
        expect(
          semanticsOf(tester, _status(status)).flagsCollection.isChecked,
          status == VisitStatus.toDo
              ? CheckedState.isTrue
              : CheckedState.isFalse,
          reason: '$status',
        );
      }
      expect(semanticsOf(tester, _status(VisitStatus.done)).label, 'Fait');
      expect(semanticsOf(tester, _status(VisitStatus.refused)).label, 'Refusé');
      expect(
        semanticsOf(tester, _status(VisitStatus.nobodyHome)).label,
        'Personne',
      );
      // ✓ and ⊘ on the first row, ✗ and ↻ on the second, each half the
      // width; ○ alone across the third.
      Rect at(VisitStatus status) => tester.getRect(_status(status));
      expect(at(VisitStatus.done).top, at(VisitStatus.refused).top);
      expect(at(VisitStatus.done).left, lessThan(at(VisitStatus.refused).left));
      expect(at(VisitStatus.nobodyHome).top, at(VisitStatus.comeBack).top);
      expect(
        at(VisitStatus.nobodyHome).left,
        lessThan(at(VisitStatus.comeBack).left),
      );
      expect(
        at(VisitStatus.nobodyHome).top,
        greaterThan(at(VisitStatus.done).bottom),
      );
      expect(
        at(VisitStatus.toDo).top,
        greaterThan(at(VisitStatus.nobodyHome).bottom),
      );
      expect(at(VisitStatus.done).width, at(VisitStatus.refused).width);
      expect(at(VisitStatus.toDo).left, at(VisitStatus.done).left);
      expect(at(VisitStatus.toDo).right, at(VisitStatus.refused).right);
      expect(at(VisitStatus.done).height, greaterThanOrEqualTo(72));
      // Never changed, never tried: no last change, no tries.
      expect(find.byKey(const Key('house.lastChange')), findsNothing);
      expect(find.byKey(const Key('house.tries')), findsNothing);
      // No hold, no sheet of details: « Transformer en immeuble… » lives in
      // edit mode only.
      expect(find.text('Transformer en immeuble…'), findsNothing);
      expect(
        semanticsOf(tester, _tile('7')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        semanticsOf(tester, _tile('1')).flagsCollection.isSelected,
        Tristate.none,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should store the status, close and tell it with « Annuler » when one '
    'is tapped, then put the house back with « Annuler »',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '7');

      await choose(tester, VisitStatus.refused);

      expect(_picker, findsNothing);
      expect(stored('7').status, VisitStatus.refused);
      expect(findArrowText('N° 7 : refusé'), findsOneWidget);
      expect(announcements(tester), ['Numéro 7, refusé']);
      expect(
        tester.getSemantics(_tile('7')).label,
        'Numéro 7, refusé, changer le statut',
      );
      expect(
        semanticsOf(tester, _tile('7')).flagsCollection.isSelected,
        Tristate.none,
      );
      expect(find.byKey(const Key('street.hint')), findsNothing);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(stored('7'), _lilas.houses[2]);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'should store nothing and tell nothing when the status the house has '
    'is tapped',
    (tester) async {
      await pick(tester, '7');

      await choose(tester, VisitStatus.toDo);

      expect(_picker, findsNothing);
      expect(streets.saved, isEmpty);
      expect(find.text('Annuler'), findsNothing);
      expect(find.byKey(const Key('street.hint')), findsOneWidget);
    },
  );

  testWidgets('should close with nothing stored with ✕ or a tap on the '
      'street', (tester) async {
    await pick(tester, '7');

    await tester.tap(find.byKey(const Key('house.close')));
    await tester.pumpAndSettle();
    expect(_picker, findsNothing);

    await tester.tap(_tile('7'));
    await tester.pumpAndSettle();
    await closeSheet(tester);

    expect(_picker, findsNothing);
    expect(streets.saved, isEmpty);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets(
    'should count one more try with « De nouveau personne » on a house '
    'nobody was home at, then put it back with « Annuler »',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '9');
      expect(
        tester.widget<Text>(find.byKey(const Key('house.tries'))).data,
        '2 passages sans personne',
      );
      expect(
        semanticsOf(tester, _status(VisitStatus.nobodyHome)).label,
        'De nouveau personne',
      );

      await choose(tester, VisitStatus.nobodyHome);

      expect(_picker, findsNothing);
      expect(stored('9').tries, tries(3));
      expect(findArrowText('N° 9 : personne (3e passage)'), findsOneWidget);
      expect(announcements(tester), ['Numéro 9, personne, 3e passage']);
      expect(
        find.descendant(of: _tile('9'), matching: find.text('×3')),
        findsOneWidget,
      );

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(stored('9').tries, tries(2));
      semantics.dispose();
    },
  );

  testWidgets(
    'should store « Refusé » with its tries reset on a house nobody was home '
    'at, put it back with « Annuler », and ring it in its picker',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '9');

      await choose(tester, VisitStatus.refused);

      expect(_picker, findsNothing);
      expect(stored('9').status, VisitStatus.refused);
      expect(stored('9').tries, NobodyHomeTries.none);
      expect(findArrowText('N° 9 : refusé'), findsOneWidget);
      expect(announcements(tester), ['Numéro 9, refusé']);
      expect(
        tester.getSemantics(_tile('9')).label,
        'Numéro 9, refusé, changer le statut',
      );
      expect(
        find.descendant(of: _tile('9'), matching: find.text('×2')),
        findsNothing,
      );

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(stored('9'), _lilas.houses[3]);

      // Refused again, its picker shows it ringed, without tries.
      await tester.tap(_tile('9'));
      await tester.pumpAndSettle();
      await choose(tester, VisitStatus.refused);
      await tester.tap(_tile('9'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('house.current'))).data,
        'Refusé',
      );
      expect(
        semanticsOf(
          tester,
          _status(VisitStatus.refused),
        ).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(find.byKey(const Key('house.tries')), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'should count the first try with « Personne » on a house to do, then '
    'offer « De nouveau personne » and say who changed it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '1');

      await choose(tester, VisitStatus.nobodyHome);

      expect(stored('1').status, VisitStatus.nobodyHome);
      expect(stored('1').tries, tries(1));
      expect(findArrowText('N° 1 : personne'), findsOneWidget);

      await tester.tap(_tile('1'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('house.current'))).data,
        'Personne',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('house.tries'))).data,
        '1 passage sans personne',
      );
      expect(
        semanticsOf(tester, _status(VisitStatus.nobodyHome)).label,
        'De nouveau personne',
      );
      final local = twoPm.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      expect(
        tester.widget<Text>(find.byKey(const Key('house.lastChange'))).data,
        'Modifié par vous · ${two(local.hour)}:${two(local.minute)}',
      );
      semantics.dispose();
    },
  );

  group('« Repasser »', () {
    testWidgets(
      'should ask when to come back, store the day and the hour, and tell '
      'it with « Annuler », which puts the house back as it was',
      (tester) async {
        await pick(tester, '1');

        await choose(tester, VisitStatus.comeBack);

        expect(stored('1').status, VisitStatus.comeBack);
        expect(_picker, findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('house.comeBackTitle')))
              .data,
          'N° 1 · quand repasser ?',
        );
        // The title says it: no « Quand repasser ? » above the days.
        expect(find.text('Quand repasser ?'), findsNothing);
        expect(summary(tester), 'Aucun jour sélectionné');
        // No snackbar under the sheet yet.
        expect(find.text('Annuler'), findsNothing);

        await tapDay(tester, '2026-11-03');
        await chooseHour(tester, '18 h');
        expect(summary(tester), 'Demain vers 18 h');
        await tester.tap(find.byKey(const Key('house.validate')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('house.comeBackTitle')), findsNothing);
        expect(stored('1').comeBack, comeBack('2026-11-03', hour: 18));
        expect(findArrowText('N° 1 : repasser'), findsOneWidget);

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();

        expect(stored('1'), _lilas.houses.first);
      },
    );

    testWidgets(
      'should still tell « Repasser » when the step is closed another way',
      (tester) async {
        await pick(tester, '7');
        await choose(tester, VisitStatus.comeBack);

        await closeSheet(tester);

        expect(find.byKey(const Key('house.comeBackTitle')), findsNothing);
        expect(stored('7').comeBack, ComeBack.withoutTime);
        expect(findArrowText('N° 7 : repasser'), findsOneWidget);
      },
    );

    testWidgets('should open the day of a house already to come back on the 📅 '
        'button, storing no status', (tester) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '5');

      await choose(tester, VisitStatus.comeBack);

      expect(streets.saved, isEmpty);
      expect(summary(tester), 'Le samedi 7 nov. vers 19 h');
      // Monday 2 November 2026 is today (the fake clock): two chips, and
      // Saturday 7 on the 📅 button.
      expect(
        find.descendant(
          of: dayChip('2026-11-02'),
          matching: find.text("Aujourd'hui"),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dayChip('2026-11-03'),
          matching: find.text('Demain'),
        ),
        findsOneWidget,
      );
      expect(dayChip('2026-11-04'), findsNothing);
      expect(dayChip('2026-11-07'), findsNothing);
      expect(
        semanticsOf(tester, otherDay).label,
        'Autre jour, samedi 7 novembre',
      );
      expect(
        semanticsOf(tester, otherDay).flagsCollection.isChecked,
        CheckedState.isTrue,
      );

      await chooseHour(tester, "Pas d'heure");
      expect(summary(tester), 'Le samedi 7 nov.');
      expect(stored('5').comeBack, comeBack('2026-11-07'));
      await tester.tap(find.byKey(const Key('house.validate')));
      await tester.pumpAndSettle();

      // No status was stored: nothing to undo.
      expect(find.text('Annuler'), findsNothing);
      expect(stored('5').status, VisitStatus.comeBack);
      semantics.dispose();
    });

    testWidgets('should leave no time when the chosen chip is tapped again', (
      tester,
    ) async {
      await pick(tester, '5');
      await choose(tester, VisitStatus.comeBack);
      await tapDay(tester, '2026-11-03');
      expect(stored('5').comeBack, comeBack('2026-11-03', hour: 19));

      await tapDay(tester, '2026-11-03');

      expect(summary(tester), 'Aucun jour sélectionné');
      expect(stored('5').comeBack, ComeBack.withoutTime);
    });

    testWidgets(
      'should store the day picked in the calendar in one write, keeping '
      'the hour',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pick(tester, '5');
        await choose(tester, VisitStatus.comeBack);

        await tester.tap(otherDay);
        await tester.pumpAndSettle();
        await tapInCalendar(tester, '15');
        await tapInCalendar(tester, 'OK');

        expect(streets.saved, hasLength(1));
        expect(stored('5').comeBack, comeBack('2026-11-15', hour: 19));
        expect(summary(tester), 'Le dimanche 15 nov. vers 19 h');
        expect(
          semanticsOf(tester, otherDay).label,
          'Autre jour, dimanche 15 novembre',
        );
        semantics.dispose();
      },
    );

    testWidgets('should select the chip of tomorrow when it is picked in the '
        'calendar', (tester) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '5');
      await choose(tester, VisitStatus.comeBack);

      await tester.tap(otherDay);
      await tester.pumpAndSettle();
      await tapInCalendar(tester, '3');
      await tapInCalendar(tester, 'OK');

      expect(stored('5').comeBack, comeBack('2026-11-03', hour: 19));
      expect(summary(tester), 'Demain vers 19 h');
      expect(
        semanticsOf(tester, dayChip('2026-11-03')).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(semanticsOf(tester, otherDay).label, 'Autre jour');
      expect(
        semanticsOf(tester, otherDay).flagsCollection.isChecked,
        CheckedState.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('should change nothing when the calendar is cancelled', (
      tester,
    ) async {
      await pick(tester, '5');
      await choose(tester, VisitStatus.comeBack);

      await tester.tap(otherDay);
      await tester.pumpAndSettle();
      await tapInCalendar(tester, '15');
      await tapInCalendar(tester, 'Annuler');

      expect(streets.saved, isEmpty);
      expect(stored('5').comeBack, comeBack('2026-11-07', hour: 19));
      expect(summary(tester), 'Le samedi 7 nov. vers 19 h');
    });

    testWidgets('should say a day gone by is past, on the 📅 button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pick(tester, '11');
      await choose(tester, VisitStatus.comeBack);

      expect(summary(tester), "C'était hier vers 19 h");
      expect(find.text('Hier'), findsNothing);
      expect(dayChip('2026-11-01'), findsNothing);
      expect(
        semanticsOf(tester, otherDay).label,
        'Autre jour, dimanche 1 novembre',
      );
      expect(
        semanticsOf(tester, otherDay).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      semantics.dispose();
    });
  });

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    for (final (number, what) in [('9', 'nobody home twice'), ('1', 'to do')]) {
      testWidgets('should show the picker of a house $what with no overflow '
          'when the text is twice as large', (tester) async {
        await openStreet(tester);
        useLargeText(tester);
        await tester.pumpAndSettle();

        await tester.tap(_tile(number));
        await tester.pumpAndSettle();

        expect(_picker, findsOneWidget);
        // « De nouveau personne » takes two lines: its row grows whole.
        expect(
          tester.getSize(_status(VisitStatus.nobodyHome)).height,
          tester.getSize(_status(VisitStatus.comeBack)).height,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('should show « quand repasser ? » with no overflow when the '
        'text is twice as large', (tester) async {
      await openStreet(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();
      await tester.tap(_tile('5'));
      await tester.pumpAndSettle();

      await choose(tester, VisitStatus.comeBack);

      expect(find.byKey(const Key('house.validate')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('should label every control of the statuses and make it 48 dp '
      'at least', (tester) async {
    await pick(tester, '9');

    await expectAccessibleControls(tester);
  });

  testWidgets('should label every control of « quand repasser ? » and make '
      'it 48 dp at least', (tester) async {
    await pick(tester, '5');
    await choose(tester, VisitStatus.comeBack);

    await expectAccessibleControls(tester);
  });
}
