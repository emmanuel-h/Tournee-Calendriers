import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/ui/components/come_back_time_picker.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

import '../../support/street_fixtures.dart';
import '../support/test_app.dart';

void main() {
  // Monday 2 November 2026.
  final today = day('2026-11-02');

  late List<CalendarDay?> days;
  late List<int?> hours;

  setUp(() {
    days = [];
    hours = [];
  });

  Future<void> pumpPicker(
    WidgetTester tester,
    ComeBack? comeBack, {
    bool enabled = true,
  }) async {
    await tester.pumpWidget(
      testApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ComeBackTimePicker(
            name: 'house',
            time: ComeBackTime.of(comeBack, today: today),
            enabled: enabled,
            onDay: days.add,
            onHour: hours.add,
          ),
        ),
      ),
    );
  }

  Finder chip(String iso) => find.byKey(ValueKey('house.comeBackDay.$iso'));
  final calendar = find.byKey(const Key('house.comeBackOtherDay'));
  final dialog = find.byType(DatePickerDialog);

  SemanticsData semanticsOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  /// The fill of the 40 dp pill drawn inside [finder].
  Color? fillOf(WidgetTester tester, Finder finder) {
    final box = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    return (box.decoration! as BoxDecoration).color;
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(calendar);
    await tester.pumpAndSettle();
  }

  Future<void> tapInDialog(WidgetTester tester, String text) async {
    await tester.tap(find.descendant(of: dialog, matching: find.text(text)));
    await tester.pumpAndSettle();
  }

  group('the day chips', () {
    testWidgets('should offer « Aujourd\'hui », « Demain » and the calendar, '
        'and no other day', (tester) async {
      await pumpPicker(tester, ComeBack.withoutTime);

      expect(
        find.descendant(
          of: chip('2026-11-02'),
          matching: find.text("Aujourd'hui"),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chip('2026-11-03'), matching: find.text('Demain')),
        findsOneWidget,
      );
      expect(chip('2026-11-04'), findsNothing);
      expect(
        find.descendant(
          of: calendar,
          matching: find.byIcon(Icons.calendar_today),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(chip('2026-11-03')).dx,
        lessThan(tester.getTopLeft(calendar).dx),
      );
    });

    testWidgets('should store the day of a chip when it is tapped', (
      tester,
    ) async {
      await pumpPicker(tester, ComeBack.withoutTime);

      await tester.tap(chip('2026-11-03'));

      expect(days, [day('2026-11-03')]);
    });

    testWidgets('should clear the day when the chosen chip is tapped again', (
      tester,
    ) async {
      await pumpPicker(tester, comeBack('2026-11-02', hour: 18));

      await tester.tap(chip('2026-11-02'));

      expect(days, [null]);
    });

    testWidgets('should fill the chosen chip only, and say it is checked', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPicker(tester, comeBack('2026-11-03'));

      expect(fillOf(tester, chip('2026-11-03')), AppColors.light.onComeBack);
      expect(fillOf(tester, chip('2026-11-02')), AppColors.light.surface);
      expect(fillOf(tester, calendar), AppColors.light.surface);
      expect(
        semanticsOf(tester, chip('2026-11-03')).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(
        semanticsOf(tester, calendar).flagsCollection.isChecked,
        CheckedState.isFalse,
      );
      expect(semanticsOf(tester, calendar).label, 'Autre jour');
      semantics.dispose();
    });
  });

  group('the calendar button', () {
    for (final (iso, spoken) in [
      ('2026-11-15', 'Autre jour, dimanche 15 novembre'),
      ('2026-11-01', 'Autre jour, dimanche 1 novembre'),
      ('2027-02-10', 'Autre jour, mercredi 10 février'),
    ]) {
      testWidgets('should be filled and name the day when $iso is chosen', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpPicker(tester, comeBack(iso, hour: 18));

        expect(fillOf(tester, calendar), AppColors.light.onComeBack);
        expect(fillOf(tester, chip('2026-11-02')), AppColors.light.surface);
        expect(fillOf(tester, chip('2026-11-03')), AppColors.light.surface);
        final data = semanticsOf(tester, calendar);
        expect(data.label, spoken);
        expect(data.flagsCollection.isChecked, CheckedState.isTrue);
        expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        semantics.dispose();
      });
    }

    testWidgets('should offer a 48 dp target', (tester) async {
      await pumpPicker(tester, null);

      expect(tester.getSize(calendar), const Size(48, 48));
    });

    testWidgets('should do nothing while the block is greyed', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPicker(tester, null, enabled: false);

      await tester.tap(calendar);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(fillOf(tester, calendar), AppColors.light.surface);
      expect(
        semanticsOf(tester, calendar).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('should open the calendar from today to 60 days ahead, on '
        'the day after tomorrow when no day is chosen', (tester) async {
      await pumpPicker(tester, ComeBack.withoutTime);

      await openCalendar(tester);

      final picker = tester.widget<DatePickerDialog>(dialog);
      expect(picker.firstDate, DateTime(2026, 11, 2));
      expect(picker.lastDate, DateTime(2027, 1, 1));
      expect(picker.initialDate, DateTime(2026, 11, 4));
      // Today as the app's clock says, not the test machine's.
      expect(picker.currentDate, DateTime(2026, 11, 2));
      // French, as the rest of the app.
      expect(find.text('novembre 2026'), findsOneWidget);
    });

    testWidgets('should open the calendar on the chosen day', (tester) async {
      await pumpPicker(tester, comeBack('2026-11-15', hour: 19));

      await openCalendar(tester);

      expect(
        tester.widget<DatePickerDialog>(dialog).initialDate,
        DateTime(2026, 11, 15),
      );
    });

    testWidgets('should store the day picked when « OK » is tapped', (
      tester,
    ) async {
      await pumpPicker(tester, comeBack('2026-11-15', hour: 19));
      await openCalendar(tester);

      await tapInDialog(tester, '20');
      await tapInDialog(tester, 'OK');

      expect(dialog, findsNothing);
      expect(days, [day('2026-11-20')]);
      expect(hours, isEmpty);
    });

    testWidgets('should store tomorrow when it is picked in the calendar', (
      tester,
    ) async {
      await pumpPicker(tester, comeBack('2026-11-15', hour: 19));
      await openCalendar(tester);

      await tapInDialog(tester, '3');
      await tapInDialog(tester, 'OK');

      expect(days, [day('2026-11-03')]);
    });

    testWidgets('should change nothing when the calendar is cancelled', (
      tester,
    ) async {
      await pumpPicker(tester, comeBack('2026-11-15', hour: 19));
      await openCalendar(tester);

      await tapInDialog(tester, '20');
      await tapInDialog(tester, 'Annuler');

      expect(dialog, findsNothing);
      expect(days, isEmpty);
      expect(hours, isEmpty);
    });

    for (final colors in [AppColors.light, AppColors.dark]) {
      testWidgets('should draw the calendar in the come-back blue '
          '(${colors.brightness.name})', (tester) async {
        await tester.pumpWidget(
          testApp(
            ComeBackTimePicker(
              name: 'house',
              time: ComeBackTime.of(ComeBack.withoutTime, today: today),
              enabled: true,
              onDay: days.add,
              onHour: hours.add,
            ),
            colors: colors,
          ),
        );
        await openCalendar(tester);

        final scheme = Theme.of(tester.element(dialog)).colorScheme;
        expect(scheme.primary, colors.onComeBack);
        expect(scheme.onPrimary, colors.surface);
      });
    }
  });
}
