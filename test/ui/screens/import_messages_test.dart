import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_messages.dart';

void main() {
  // The French strings, without building a widget.
  final l10n = lookupAppLocalizations(const Locale('fr'));

  group('importDoneMessage', () {
    test('should count the new streets when none came back', () {
      expect(
        importDoneMessage(l10n, const ImportSummary(imported: 3, failed: 0)),
        '3 rues importées',
      );
    });

    test('should count the restored streets when no street is new', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 0, restored: 2, failed: 0),
        ),
        '2 rues restaurées',
      );
    });

    test('should count both when streets are new and restored', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 2, restored: 1, failed: 0),
        ),
        '2 rues importées, 1 restaurée',
      );
    });
  });
}
