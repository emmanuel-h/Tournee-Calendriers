import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_view.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/come_backs/come_back_words.dart';

import '../../domain/come_back/come_back_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    // In the app, the Material translations load the French month names;
    // here nothing does, so they are loaded by hand.
    await initializeDateFormatting('fr');
    l10n = lookupAppLocalizations(const Locale('fr'));
  });

  final place = ComeBackPlace(street: nationaleId, number: n('12'));
  final later = ComeBackDay(day('2026-10-27'), DayFromToday.later);
  final earlier = ComeBackDay(day('2026-10-14'), DayFromToday.earlier);

  group('lowerFirst', () {
    test('should lower the first letter only', () {
      expect(lowerFirst('Aujourd\'hui vers 19 h'), 'aujourd\'hui vers 19 h');
      expect(lowerFirst(''), '');
    });
  });

  group('rows', () {
    test('should say a later day in the pill and the semantics', () {
      final row = ComeBackRow(
        place: place,
        streetName: 'Rue Nationale',
        number: '12',
        day: later,
        hour: 18,
      );

      expect(
        comeBackRingHint(l10n, row),
        'N° 12 · repasser le mardi 27 oct. vers 18 h',
      );
      expect(
        comeBackRowSemantics(l10n, row),
        'Le mardi 27 oct. vers 18 h, 12 Rue Nationale',
      );
      expect(comeBackRowDetails(l10n, row), isNull);
    });

    test('should say a day long gone under the row', () {
      final row = ComeBackRow(
        place: place,
        streetName: 'Rue Nationale',
        number: '12',
        day: earlier,
        by: const ChangedByMember('Léa'),
      );

      expect(
        comeBackRowDetails(l10n, row),
        'C\'était le mercredi 14 oct. · par Léa',
      );
      expect(
        comeBackRingHint(l10n, row),
        'N° 12 · c\'était le mercredi 14 oct.',
      );
    });

    test('should say only the address of a « repasser » without day', () {
      final row = ComeBackRow(
        place: place,
        streetName: 'Rue Nationale',
        number: '12',
        rings: true,
      );

      expect(comeBackRingHint(l10n, row), 'N° 12 · à repasser');
      expect(comeBackRowSemantics(l10n, row), '12 Rue Nationale, rappel prévu');
      expect(comeBackRowDetails(l10n, row), isNull);
    });
  });

  group('reminderText', () {
    final door = entry(
      pasteurId,
      '8',
      comeBack('2026-10-24'),
      door: DwellingKey(escA, 5, d('51')),
    );
    final lilas = entry(lilasId, '12', comeBack('2026-10-24'));

    test('should say the hour and the address', () {
      final text = reminderText(
        l10n,
        HourReminder(
          DateTime(2026, 10, 24, 18, 45),
          entry(nationaleId, '12', comeBack('2026-10-24', hour: 19)),
        ),
      );

      expect(text.title, 'Repasser vers 19 h');
      expect(text.body, '12 Rue Nationale');
    });

    test('should count the houses of the day, one address a line', () {
      final text = reminderText(
        l10n,
        DayReminder(DateTime(2026, 10, 24, 9), saturday, [lilas, door]),
      );

      expect(text.title, '2 maisons à repasser aujourd\'hui');
      expect(text.body, '12 Rue des Lilas\nPorte 51 · 8 Rue Pasteur');
    });

    test('should say one house alone', () {
      expect(
        reminderText(
          l10n,
          DayReminder(DateTime(2026, 10, 24, 9), saturday, [lilas]),
        ).title,
        '1 maison à repasser aujourd\'hui',
      );
    });

    test('should name no person', () {
      final text = reminderText(
        l10n,
        DayReminder(DateTime(2026, 10, 24, 9), saturday, [
          entry(lilasId, '12', ComeBack.withoutTime),
        ]),
      );

      expect('${text.title} ${text.body}', isNot(contains('par')));
    });
  });
}
