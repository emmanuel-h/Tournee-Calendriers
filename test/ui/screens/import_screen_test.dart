import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/street_part/street_part_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show leaId, sectorId, team;
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_part_index.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

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
  var index = FakeStreetPartIndex();

  Finder street(BanStreetId id) =>
      find.byKey(ValueKey('import.street.${id.value}'));
  bool checked(WidgetTester tester, BanStreetId id) =>
      tester.widget<CheckboxListTile>(street(id)).value!;

  /// Opens the « Liste » tab of « Ajouter des rues » from Accueil of the
  /// 49, a secteur created before the communes (so the commune is searched
  /// in a field, PLAN §5.4), and chooses Villefranche-sur-Saône.
  Future<void> openVillefranche(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          // Léa of the team: only a member prepares the secteur.
          member: leaId,
          streets: streets,
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sectorId)),
          ),
          directory: directory,
          index: index,
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
    // From Secteur, as the member would (PLAN §5.14).
    await openAddStreets(tester);
    await tester.tap(find.byKey(const Key('addStreets.tab.list')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    index = FakeStreetPartIndex();
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

  testWidgets('should say under a street ticked which part another secteur '
      'holds', (tester) async {
    index.others[_morin] = [
      SectorPart(
        sector: valueOf(SectorNumber.create(3)),
        centre: valueOf(RescueCentre.create('CS Arnas')),
        part: StreetPart.whole,
      ),
    ];
    await openVillefranche(tester);

    await tester.tap(street(_morin));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ValueKey('import.others.${_morin.value}')),
        matching: find.text('Secteur 3 (CS Arnas)\u00a0: toute la rue'),
      ),
      findsOneWidget,
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
    expect(find.text('Ajouter 1 rue'), findsOneWidget);

    await tester.tap(find.text('Tout cocher'));
    await tester.pump();

    expect(find.text('3 RUES · 3 COCHÉES'), findsOneWidget);
    expect(find.text('Ajouter 3 rues'), findsOneWidget);
    expect(find.text('Tout décocher'), findsOneWidget);

    await tester.tap(find.text('Tout décocher'));
    await tester.pump();

    expect(checked(tester, _morin), isFalse);
    expect(find.text('3 RUES · 0 COCHÉE'), findsOneWidget);
  });

  testWidgets(
    'should show a street already in the secteur ticked, disabled and '
    'labelled',
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
          matching: find.text('déjà dans le secteur'),
        ),
        findsOneWidget,
      );

      await tester.tap(street(_morin));
      await tester.pump();

      expect(find.text('3 RUES · 0 COCHÉE'), findsOneWidget);
    },
  );

  testWidgets('should bring a street back from the Corbeille with its marks', (
    tester,
  ) async {
    final morin = valueOf(
      Street.create(
        id: StreetId('s'),
        name: 'Rue Pierre Morin',
        commune: villefranche,
        banId: _morin,
        houses: [
          House(number: n('1'), status: VisitStatus.done),
          House(number: n('2')),
        ],
      ),
    );
    await streets.add(morin.delete(by: lea, at: twoPm).$1);
    await openVillefranche(tester);

    final tile = tester.widget<CheckboxListTile>(street(_morin));
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNotNull);
    expect(
      find.descendant(
        of: street(_morin),
        matching: find.text('dans la Corbeille'),
      ),
      findsOneWidget,
    );

    await tester.tap(street(_morin));
    await tester.pump();
    await tester.tap(find.text('Ajouter 1 rue'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsNothing);
    expect(find.text('1 rue restaurée'), findsOneWidget);
    // Back on Secteur, where « Ajouter des rues » was opened; Accueil
    // under it.
    expect(find.byType(TeamScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Rue Pierre Morin, 1 sur 2 faits'),
      findsOneWidget,
    );
  });

  testWidgets(
    'should go back to Secteur when every street is added, the new streets '
    'in Accueil',
    (tester) async {
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.tap(street(_bordelan));
      await tester.pump();

      await tester.tap(find.text('Ajouter 2 rues'));
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsNothing);
      expect(find.text('2 rues ajoutées au secteur'), findsOneWidget);
      expect(find.byType(TeamScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      // In the one list of the secteur's streets.
      expect(find.byKey(const Key('home.header')), findsOneWidget);
      final morin = find.bySemanticsLabel('Rue Pierre Morin, 0 sur 3 faits');
      await tester.scrollUntilVisible(
        morin,
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('home.panel.list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(morin, findsOneWidget);
    },
  );

  testWidgets(
    'should stay with the failed street ticked and say why when some fail',
    (tester) async {
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.tap(street(_bonnet));
      await tester.pump();

      await tester.tap(find.text('Ajouter 2 rues'));
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsOneWidget);
      expect(
        find.text(
          '1 rue ajoutée, 1 en échec. Pas de réseau. Réessayez quand le '
          'téléphone capte. Les rues encore cochées restent à ajouter.',
        ),
        findsOneWidget,
      );
      expect(checked(tester, _bonnet), isTrue);
      expect(find.text('Ajouter 1 rue'), findsOneWidget);
    },
  );

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await openVillefranche(tester);

    await expectAccessibleControls(tester);
  });

  group('the part of a street (PLAN §5.15)', () {
    Finder partLink(BanStreetId id) =>
        find.byKey(ValueKey('import.part.${id.value}'));
    Finder count(BanStreetId id) =>
        find.byKey(ValueKey('import.count.${id.value}'));

    /// A tap on the part link of [id], scrolled into view first.
    Future<void> openPart(WidgetTester tester, BanStreetId id) async {
      await tester.ensureVisible(partLink(id));
      await tester.pumpAndSettle();
      await tester.tap(partLink(id));
      await tester.pumpAndSettle();
    }

    testWidgets('should offer the whole street under a street ticked '
        'only', (tester) async {
      await openVillefranche(tester);
      expect(partLink(_morin), findsNothing);

      await tester.tap(street(_morin));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: partLink(_morin),
          matching: find.text('Toute la rue'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Text>(count(_morin)).data, '19 n°');
    });

    testWidgets('should read the numbers, choose the part, then show it and '
        'add only its numbers', (tester) async {
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.pumpAndSettle();

      await openPart(tester, _morin);
      expect(find.byType(StreetPartScreen), findsOneWidget);
      // « Impairs », « Aucun impair », « Valider »: the evens only.
      await tester.tap(find.byKey(const Key('part.sides.odd')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.nothing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.validate')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: partLink(_morin),
          matching: find.text('Tous les pairs'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Text>(count(_morin)).data, '1 n° sur 3');
      await tester.tap(find.byKey(const Key('import.button')));
      await tester.pumpAndSettle();
      final added = streets.added.single;
      expect(added.part, part(odd: SidePart.none, even: SidePart.all));
      expect(added.houses.map((house) => house.number), [n('2')]);
    });

    testWidgets('should say a connection is needed to read the numbers', (
      tester,
    ) async {
      await openVillefranche(tester);
      await tester.tap(street(_bonnet));
      await tester.pumpAndSettle();

      await openPart(tester, _bonnet);

      expect(find.byType(StreetPartScreen), findsNothing);
      expect(
        find.text('Connexion nécessaire pour lire les numéros de la rue.'),
        findsOneWidget,
      );
    });

    testWidgets('should say the numbers cannot be read for now', (
      tester,
    ) async {
      directory.streets[_morin] = const Err(
        AddressDirectoryFailure.serviceError,
      );
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.pumpAndSettle();

      await openPart(tester, _morin);

      expect(
        find.text(
          'Impossible de lire les numéros de la rue pour l\'instant. '
          'Réessayez plus tard.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should change nothing when « Partie de la rue » is left '
        'with ✕', (tester) async {
      await openVillefranche(tester);
      await tester.tap(street(_morin));
      await tester.pumpAndSettle();
      await openPart(tester, _morin);

      await tester.tap(find.byKey(const Key('part.close')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: partLink(_morin),
          matching: find.text('Toute la rue'),
        ),
        findsOneWidget,
      );
    });
  });
}
