import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_messages.dart';

void main() {
  // The French strings, without building a widget.
  final l10n = lookupAppLocalizations(const Locale('fr'));

  group('importDoneMessage', () {
    test('should say the streets were added to the secteur', () {
      expect(
        importDoneMessage(l10n, const ImportSummary(imported: 3, failed: 0)),
        '3 rues ajoutées au secteur',
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

    test('should count one restored street alone the same way', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 0, restored: 1, failed: 0),
        ),
        '1 rue restaurée',
      );
    });

    test('should count both added and restored streets', () {
      expect(
        importDoneMessage(
          l10n,
          const ImportSummary(imported: 2, restored: 1, failed: 0),
        ),
        '2 rues ajoutées, 1 restaurée',
      );
    });
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
      ),
      '2 rues ajoutées, 1 en échec. ${l10n.addressNoNetwork} '
      'Les rues encore cochées restent à ajouter.',
    );
  });

  test('should give the reason the service gave when some failed', () {
    expect(
      importPartialMessage(
        l10n,
        const ImportSummary(
          imported: 2,
          failed: 1,
          failure: ImportProblem.serviceError,
        ),
      ),
      '2 rues ajoutées, 1 en échec. ${l10n.addressServiceError} '
      'Les rues encore cochées restent à ajouter.',
    );
  });
}
