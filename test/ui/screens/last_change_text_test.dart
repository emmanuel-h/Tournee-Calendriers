import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/last_change_text.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    // In the app, the Material translations load the French month names;
    // here nothing does, so they are loaded by hand.
    await initializeDateFormatting('fr');
    l10n = lookupAppLocalizations(const Locale('fr'));
  });

  test('should give the time only when the change was made today', () {
    expect(
      lastChangeText(l10n, ChangedToday(DateTime(2026, 10, 4, 14, 2))),
      'Modifié à 14:02',
    );
  });

  test('should pad the hour and minutes with a zero when below ten', () {
    expect(
      lastChangeText(l10n, ChangedToday(DateTime(2026, 10, 4, 9, 5))),
      'Modifié à 09:05',
    );
  });

  test('should give the day in French when the change was made earlier', () {
    expect(
      lastChangeText(l10n, ChangedEarlier(DateTime(2026, 10, 3, 14, 2))),
      'Modifié le 3 oct. à 14:02',
    );
  });

  test('should write a short month without a dot when it has none', () {
    expect(
      lastChangeText(l10n, ChangedEarlier(DateTime(2026, 5, 21, 18, 40))),
      'Modifié le 21 mai à 18:40',
    );
  });
}
