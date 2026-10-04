import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

final _morin = BanStreetId('69264_1460');
final _bonnet = BanStreetId('69264_0682');
final _bordelan = BanStreetId('69264_0246');

DirectoryStreet _listed(BanStreetId id, String name, int count) =>
    DirectoryStreet(
      id: id,
      name: valueOf(StreetName.create(name)),
      numberCount: count,
    );

StreetNumbers _numbers(BanStreetId id, String name) => StreetNumbers(
  id: id,
  name: valueOf(StreetName.create(name)),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1')),
    DirectoryNumber(number: n('2')),
    DirectoryNumber(number: n('3')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;

  Finder street(BanStreetId id) =>
      find.byKey(ValueKey('import.street.${id.value}'));
  bool checked(WidgetTester tester, BanStreetId id) =>
      tester.widget<CheckboxListTile>(street(id)).value!;

  /// Opens the import screen from the start screen and chooses
  /// Villefranche-sur-Saône.
  Future<void> openVillefranche(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          directory: directory,
          communes: FakeCommuneSearch(
            answers: {
              'Villef': Ok([
                CommuneMatch(commune: villefranche, postcodes: const ['69400']),
              ]),
            },
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    streets = FakeStreetRepository();
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(
          CommuneStreets(
            commune: villefranche,
            streets: [
              _listed(_morin, 'Rue Pierre Morin', 19),
              _listed(_bonnet, 'Rue des Frères Bonnet', 403),
              _listed(_bordelan, 'Petit Chemin de Bordelan', 8),
            ],
            skippedStreets: 0,
          ),
        ),
      },
      streets: {
        _morin: Ok(_numbers(_morin, 'Rue Pierre Morin')),
        _bonnet: const Err(AddressDirectoryFailure.noNetwork),
        _bordelan: Ok(_numbers(_bordelan, 'Petit Chemin de Bordelan')),
      },
    );
  });

  testWidgets(
    'should suggest the commune then list its streets when a commune is typed and chosen',
    (tester) async {
      await openVillefranche(tester);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('import.commune')))
            .controller!
            .text,
        'Villefranche-sur-Saône (69400)',
      );
      // The keyboard closes so the checklist has the room.
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('3 RUES · 0 COCHÉE'), findsOneWidget);
      expect(find.text('Rue des Frères Bonnet'), findsOneWidget);
      expect(find.text('403 n°'), findsOneWidget);
      expect(tester.getSize(street(_morin)).height, greaterThanOrEqualTo(56));
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('import.button')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.enabled, isFalse);
    },
  );

  testWidgets('should count the ticked streets when ticked and unticked', (
    tester,
  ) async {
    await openVillefranche(tester);

    await tester.tap(street(_morin));
    await tester.pump();

    expect(checked(tester, _morin), isTrue);
    expect(find.text('3 RUES · 1 COCHÉE'), findsOneWidget);
    expect(find.text('Importer 1 rue'), findsOneWidget);

    await tester.tap(find.text('Tout cocher'));
    await tester.pump();

    expect(find.text('3 RUES · 3 COCHÉES'), findsOneWidget);
    expect(find.text('Importer 3 rues'), findsOneWidget);
    expect(find.text('Tout décocher'), findsOneWidget);

    await tester.tap(find.text('Tout décocher'));
    await tester.pump();

    expect(checked(tester, _morin), isFalse);
    expect(find.text('3 RUES · 0 COCHÉE'), findsOneWidget);
  });

  testWidgets(
    'should show a street already on the phone ticked, disabled and labelled',
    (tester) async {
      await streets.add(
        valueOf(
          Street.create(
            id: StreetId('s'),
            name: 'Rue Pierre Morin',
            commune: villefranche,
            banId: _morin,
          ),
        ),
      );
      await openVillefranche(tester);

      final tile = tester.widget<CheckboxListTile>(street(_morin));
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNull);
      expect(
        find.descendant(
          of: street(_morin),
          matching: find.text('déjà importée'),
        ),
        findsOneWidget,
      );

      await tester.tap(street(_morin));
      await tester.pump();

      expect(find.text('3 RUES · 0 COCHÉE'), findsOneWidget);
    },
  );

  testWidgets(
    'should go back to the list with the new streets when every street is imported',
    (tester) async {
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.tap(street(_bordelan));
      await tester.pump();

      await tester.tap(find.text('Importer 2 rues'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportScreen), findsNothing);
      expect(find.text('2 rues importées'), findsOneWidget);
      expect(find.text('Mes rues · 2'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Rue Pierre Morin, 0 sur 3 faits'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should stay with the failed street ticked and say why when some fail',
    (tester) async {
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.tap(street(_bonnet));
      await tester.pump();

      await tester.tap(find.text('Importer 2 rues'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportScreen), findsOneWidget);
      expect(
        find.text(
          '1 rue importée, 1 en échec. Pas de réseau. Réessayez quand le '
          'téléphone capte. Les rues encore cochées restent à importer.',
        ),
        findsOneWidget,
      );
      expect(checked(tester, _bonnet), isTrue);
      expect(find.text('Importer 1 rue'), findsOneWidget);
    },
  );
}
