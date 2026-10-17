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
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 3, failed: 0),
          inTournee: false,
        ),
        '3 rues importées',
      );
    });

    test('should count the restored streets when no street is new', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 0, restored: 2, failed: 0),
          inTournee: false,
        ),
        '2 rues restaurées',
      );
    });

    test('should count both when streets are new and restored', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 2, restored: 1, failed: 0),
          inTournee: false,
        ),
        '2 rues importées, 1 restaurée',
      );
    });
  });

  group('in a tournée', () {
    test('should say the streets were added to the tournée', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 3, failed: 0),
          inTournee: true,
        ),
        '3 rues ajoutées à la tournée',
      );
    });

    test('should count the restored streets alone the same way', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 0, restored: 1, failed: 0),
          inTournee: true,
        ),
        '1 rue restaurée',
      );
    });

    test('should count both added and restored streets', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 2, restored: 1, failed: 0),
          inTournee: true,
        ),
        '2 rues ajoutées, 1 restaurée',
      );
    });

    test('should say which streets remain to add when some failed', () {
      expect(
        importPartialMessage(
          l10n,
          const ImportSummary(
            imported: 1,
            restored: 1,
            failed: 1,
            failure: ImportProblem.noNetwork,
          ),
          inTournee: true,
        ),
        '2 rues ajoutées, 1 en échec. ${l10n.addressNoNetwork} '
        'Les rues encore cochées restent à ajouter.',
      );
    });
  });

  test('should say which streets remain to import when some failed', () {
    expect(
      importPartialMessage(
        l10n,
        const ImportSummary(
          imported: 2,
          failed: 1,
          failure: ImportProblem.serviceError,
        ),
        inTournee: false,
      ),
      '2 rues importées, 1 en échec. ${l10n.addressServiceError} '
      'Les rues encore cochées restent à importer.',
    );
  });
}
