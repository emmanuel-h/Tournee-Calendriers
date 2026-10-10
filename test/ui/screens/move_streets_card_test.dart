import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/move_streets/move_streets_state.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations_fr.dart';
import 'package:tournee_calendriers/ui/screens/start/move_streets_card.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart' show leaId, team;
import '../../support/fakes/fake_moved_streets_log.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

// The card « 2 rues sont enregistrées sur ce téléphone. » of the start
// screen (PLAN §5.0).
void main() {
  Street street(String id, String name, String banId) => valueOf(
    Street.create(
      id: StreetId(id),
      name: name,
      commune: villefranche,
      banId: BanStreetId(banId),
    ),
  );

  late FakeStreetRepository tourneeStreets;
  late FakeMovedStreetsLog log;

  /// Léa's phone with the 49 open, two streets kept on the phone, and the
  /// 49 holding [inTournee].
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Street> inTournee = const [],
  }) async {
    tourneeStreets = FakeStreetRepository(inTournee);
    log = FakeMovedStreetsLog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: tourneeStreets,
          phoneStreets: FakeStreetRepository([
            street('s1', 'Rue Nationale', '69264_0420'),
            street('s2', 'Rue Pierre Morin', '69264_1460'),
          ]),
          movedStreets: log,
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
          ),
          tournees: FakeTourneeRepository([team()]),
          member: leaId,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  final card = find.byKey(const Key('start.moveStreetsCard'));

  testWidgets('should offer the phone streets above the tournée\'s', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.text('2 rues sont enregistrées sur ce téléphone.'),
      findsOneWidget,
    );
    expect(find.text('Les ajouter à la tournée'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    // Above the empty tournée's message.
    expect(
      tester.getBottomLeft(card).dy,
      lessThan(tester.getTopLeft(find.text("Aucune rue pour l'instant")).dy),
    );
    expect(
      tester.getSize(find.byKey(const Key('start.moveStreetsLater'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('should add them to the tournée, say so and go away', (
    tester,
  ) async {
    await pumpApp(tester);
    tourneeStreets.holdAdds = Completer<void>();

    await tester.tap(find.byKey(const Key('start.moveStreets')));
    await tester.pump();
    expect(find.text('Ajout en cours… 0/2'), findsOneWidget);
    expect(find.text('Les ajouter à la tournée'), findsNothing);
    tourneeStreets.holdAdds!.complete();
    await tester.pumpAndSettle();

    expect(find.text('2 rues ajoutées à la tournée'), findsOneWidget);
    expect(card, findsNothing);
    expect(find.text('Rue Nationale'), findsOneWidget);
    expect(find.text('Rue Pierre Morin'), findsOneWidget);
    expect(log.remembered, [tournee49.id]);
  });

  testWidgets('should count the streets the tournée already had', (
    tester,
  ) async {
    await pumpApp(
      tester,
      inTournee: [street('t-1', 'Rue Nationale', '69264_0420')],
    );

    await tester.tap(find.byKey(const Key('start.moveStreets')));
    await tester.pumpAndSettle();

    expect(find.text('1 rue ajoutée, 1 déjà dans la tournée'), findsOneWidget);
    expect(tourneeStreets.added.single.id, StreetId('s2'));
  });

  testWidgets('should hide the card on « Plus tard », moving nothing', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start.moveStreetsLater')));
    await tester.pumpAndSettle();

    expect(card, findsNothing);
    expect(tourneeStreets.added, isEmpty);
    expect(log.remembered, isEmpty);
  });

  test('should word every outcome of the move', () {
    final l10n = AppLocalizationsFr();

    expect(
      movedStreetsMessage(l10n, const MovedSummary(moved: 1, alreadyThere: 0)),
      '1 rue ajoutée à la tournée',
    );
    expect(
      movedStreetsMessage(l10n, const MovedSummary(moved: 0, alreadyThere: 3)),
      'Aucune rue ajoutée, 3 déjà dans la tournée',
    );
    expect(
      movedStreetsMessage(l10n, const MovedSummary(moved: 10, alreadyThere: 2)),
      '10 rues ajoutées, 2 déjà dans la tournée',
    );
  });
}
