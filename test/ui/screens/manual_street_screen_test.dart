// « Rue à la main » (PLAN §5.5, Manual mockup): a street typed in, offline.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/manual_street_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;
import '../support/app_overrides.dart';

void main() {
  late FakeStreetRepository streets;

  /// « Rue à la main » on Léa's phone, the 49 open with [communes] and
  /// [existing] streets.
  Future<void> pumpManual(
    WidgetTester tester, {
    List<TourneeCommune> communes = const [],
    List<Street> existing = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository(existing);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          member: leaId,
          communes: FakeCommuneSearch(
            answers: {
              'Villef': Ok([
                CommuneMatch(commune: villefranche, postcodes: const ['69400']),
              ]),
            },
          ),
          tournees: FakeTourneeRepository([team(communes: communes)]),
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(tournee49).open(tourneeId)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addStreets.manual')));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key('manual.$key')), text);
    await tester.pumpAndSettle();
  }

  bool addEnabled(WidgetTester tester) => tester
      .widget<ButtonStyleButton>(
        find.descendant(
          of: find.byKey(const Key('manual.add')),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      )
      .enabled;

  testWidgets('should preview the numbers and add the street for the '
      'member, then go back to the map', (tester) async {
    await pumpManual(tester, communes: [villefrancheCommune, gleizeCommune]);
    expect(
      find.text(
        'Fonctionne sans réseau. La rue n\'aura pas de tracé sur '
        'la carte.',
      ),
      findsOneWidget,
    );
    expect(addEnabled(tester), isFalse);

    await type(tester, 'name', 'Chemin des Vignes');
    await type(tester, 'from', '1');
    await type(tester, 'to', '5');
    await tester.tap(find.byKey(const Key('manual.sides.odd')));
    await tester.pumpAndSettle();
    await type(tester, 'extras', '12bis');

    expect(find.text('APERÇU · 4 NUMÉROS'), findsOneWidget);
    expect(find.text('1, 3, 5, 12bis'), findsOneWidget);
    expect(addEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('manual.add')));
    await tester.pumpAndSettle();

    final street = streets.added.single;
    expect(street.name.text, 'Chemin des Vignes');
    expect(street.commune, villefranche);
    expect(street.assignees, {leaId});
    expect(find.byType(ManualStreetScreen), findsNothing);
    expect(find.byType(AddStreetsScreen), findsOneWidget);
    expect(
      find.text('« Chemin des Vignes » ajoutée à vos rues.'),
      findsOneWidget,
    );
  });

  testWidgets('should add the street in the commune chosen', (tester) async {
    await pumpManual(tester, communes: [villefrancheCommune, gleizeCommune]);
    await type(tester, 'name', 'Chemin des Vignes');
    await type(tester, 'from', '1');

    await tester.tap(find.byKey(const Key('manual.commune')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gleizé').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual.add')));
    await tester.pumpAndSettle();

    expect(streets.added.single.commune, gleizeCommune.commune);
  });

  testWidgets('should name the number that is wrong', (tester) async {
    await pumpManual(tester, communes: [villefrancheCommune]);
    await type(tester, 'name', 'Chemin des Vignes');

    await type(tester, 'extras', '12é');

    expect(find.byKey(const Key('manual.refusal')), findsOneWidget);
    expect(addEnabled(tester), isFalse);
  });

  testWidgets('should say a name is too long', (tester) async {
    await pumpManual(tester, communes: [villefrancheCommune]);

    await type(tester, 'name', 'a' * 151);

    expect(find.text('Nom limité à 150 caractères.'), findsOneWidget);
  });

  testWidgets('should offer the communes of the streets for a tournée '
      'without commune', (tester) async {
    await pumpManual(
      tester,
      existing: [
        valueOf(
          Street.create(
            id: StreetId('bourg'),
            name: 'Rue du Bourg',
            commune: gleizeCommune.commune,
          ),
        ),
      ],
    );

    expect(find.text('Gleizé'), findsOneWidget);
    expect(find.byKey(const Key('communes.field')), findsNothing);
  });

  testWidgets('should search the commune of a tournée without commune nor '
      'street', (tester) async {
    await pumpManual(tester);
    expect(
      find.text(
        'La tournée n\'a pas encore de commune : cherchez celle de la '
        'rue.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('communes.field')), 'Villef');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('communes.suggestion.69264')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual.communeFound')), findsOneWidget);
    await type(tester, 'name', 'Chemin des Vignes');
    await type(tester, 'from', '1');
    await tester.tap(find.byKey(const Key('manual.add')));
    await tester.pumpAndSettle();

    expect(streets.added.single.commune, villefranche);
  });
}
