import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

final _morin = BanStreetId('69264_1460');
final _bordelan = BanStreetId('69264_0246');
final _bourg = BanStreetId('69092_0010');

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
  numbers: [DirectoryNumber(number: n('1'))],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

void main() {
  late FakeStreetRepository streets;

  /// The start screen of a phone where the 49, covering [communes], is
  /// open; Rue Pierre Morin is already in it.
  Future<void> pumpStart(
    WidgetTester tester,
    List<TourneeCommune> communes,
  ) async {
    streets = FakeStreetRepository([
      valueOf(
        Street.create(
          id: StreetId('morin'),
          name: 'Rue Pierre Morin',
          commune: villefranche,
          banId: _morin,
        ),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          tournees: FakeTourneeRepository([team(communes: communes)]),
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(tournee49).open(tourneeId)),
          ),
          directory: FakeAddressDirectory(
            communes: {
              '69264': Ok(
                CommuneStreets(
                  commune: villefranche,
                  streets: [
                    _listed(_morin, 'Rue Pierre Morin', 19),
                    _listed(_bordelan, 'Petit Chemin de Bordelan', 8),
                  ],
                  skippedStreets: 0,
                ),
              ),
              '69092': Ok(
                CommuneStreets(
                  commune: gleizeCommune.commune,
                  streets: [_listed(_bourg, 'Rue du Bourg', 30)],
                  skippedStreets: 0,
                ),
              ),
            },
            streets: {
              _bordelan: Ok(_numbers(_bordelan, 'Petit Chemin de Bordelan')),
            },
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should open « Ajouter des rues » on the list of the '
      'tournée\'s first commune, a chip per commune', (tester) async {
    await pumpStart(tester, [villefrancheCommune, gleizeCommune]);
    expect(find.text('Ajouter des rues'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Carte'), findsOneWidget);
    expect(find.bySemanticsLabel('Liste'), findsOneWidget);
    expect(find.byType(ImportList), findsOneWidget);
    expect(find.byKey(const Key('import.commune')), findsNothing);
    expect(find.byKey(const ValueKey('import.commune.69264')), findsOneWidget);
    expect(find.byKey(const ValueKey('import.commune.69092')), findsOneWidget);
    expect(find.text('déjà dans la tournée'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import.commune.69092')));
    await tester.pumpAndSettle();

    expect(find.text('Rue du Bourg'), findsOneWidget);
    expect(find.text('Rue Pierre Morin'), findsNothing);
  });

  testWidgets('should show no chip for a single commune, and add the streets '
      'ticked to the tournée', (tester) async {
    await pumpStart(tester, [villefrancheCommune]);
    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import.commune.69264')), findsNothing);
    await tester.tap(find.byKey(ValueKey('import.street.${_bordelan.value}')));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter 1 rue'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import.button')));
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsNothing);
    expect(find.text('1 rue ajoutée à la tournée'), findsOneWidget);
    expect(await streets.findByBanId(_bordelan), isNotNull);
  });

  testWidgets('should search the commune of a tournée without commune', (
    tester,
  ) async {
    await pumpStart(tester, []);
    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import.commune')), findsOneWidget);
  });

  testWidgets('should close with ✕', (tester) async {
    await pumpStart(tester, [villefrancheCommune]);
    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsNothing);
  });
}
