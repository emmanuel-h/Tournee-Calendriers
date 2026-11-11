// The message the app shows once at start-up when the phone's file of
// tournées could not be read (#143), rather than starting silently with
// none.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/ui/app.dart';

import '../domain/sector/my_sectors_fixtures.dart';
import '../support/fakes/fake_my_sectors_store.dart';
import '../support/fakes/fake_open_round_store.dart';
import '../support/results.dart';
import 'support/app_overrides.dart';

const _nbsp = '\u00a0';

const _message =
    "Les tournées gardées sur ce téléphone n'ont pas pu être relues"
    '$_nbsp: leurs dons sont perdus.';

void main() {
  Future<void> pumpApp(WidgetTester tester, {required bool unreadable}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
          rounds: FakeOpenRoundStore()..unreadableAtStart = unreadable,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should say on Accueil that the tournées could not be read', (
    tester,
  ) async {
    await pumpApp(tester, unreadable: true);

    expect(find.text(_message), findsOneWidget);
    expect(find.text('Secteur 49 · 2026'), findsOneWidget);
  });

  testWidgets('should say it only once', (tester) async {
    await pumpApp(tester, unreadable: true);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // Built again (a new theme would do it): nothing more to say.
    tester.element(find.byType(TourneeApp)).markNeedsBuild();
    await tester.pumpAndSettle();

    expect(find.text(_message), findsNothing);
  });

  testWidgets('should say nothing when they were read', (tester) async {
    await pumpApp(tester, unreadable: false);

    expect(find.textContaining('pas pu être relues'), findsNothing);
  });
}
