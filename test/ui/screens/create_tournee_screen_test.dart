import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/navigation.dart';

void main() {
  final csVillefrancheSurSaone = valueOf(
    RescueCentre.create('CS Villefranche-sur-Saône'),
  );
  late FakeTourneeDirectory directory;
  late FakeTourneeRepository tournees;
  late FakeMyTourneesStore store;

  /// Opens « Nouvelle tournée » over the start screen on Léa's phone,
  /// signed in, her name kept.
  Future<void> open(WidgetTester tester) async {
    tournees = FakeTourneeRepository();
    store = FakeMyTourneesStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          tourneeDirectory: directory,
          tournees: tournees,
          myTournees: store,
          settings: FakePhoneSettings(memberName: nameOf('Léa')),
          account: FakeMemberAccount(signedInMember: MemberId('uid-lea')),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(StartScreen))),
      AppRoutes.create,
    );
    await tester.pumpAndSettle();
  }

  /// Types « villef » and picks the CS Villefranche, then types 49.
  Future<void> fillIn(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('create.centre')), 'villef');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create.centre.villefranche')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create.number')), '49');
    await tester.pumpAndSettle();
  }

  final createButton = find.byKey(const Key('create.create'));

  setUp(() {
    directory = FakeTourneeDirectory()
      ..centres = [csVillefranche, csVillefrancheSurSaone];
  });

  testWidgets(
    'should list the known centres the text names and offer to add it',
    (tester) async {
      await open(tester);

      await tester.enterText(find.byKey(const Key('create.centre')), 'villef');
      await tester.pumpAndSettle();

      expect(find.text('CS Villefranche'), findsOneWidget);
      expect(find.text('CS Villefranche-sur-Saône'), findsOneWidget);
      expect(find.text('Ajouter «\u00a0villef\u00a0»'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ajouter «\u00a0villef\u00a0»'),
        findsOneWidget,
      );
      expect(isEnabled(tester, createButton), isFalse);
    },
  );

  testWidgets(
    'should say the tournée exists, refuse « Créer » and offer to join '
    'when the number is taken in the centre',
    (tester) async {
      directory.taken.add((csVillefranche.key, number49));
      await open(tester);

      await fillIn(tester);

      expect(
        find.text('La tournée 49 du CS Villefranche existe déjà.'),
        findsOneWidget,
      );
      expect(
        find.text(
          "Demandez le code ou le QR code à la personne qui l'a créée.",
        ),
        findsOneWidget,
      );
      expect(isEnabled(tester, createButton), isFalse);

      await tester.tap(find.byKey(const Key('create.joinWithCode')));
      await tester.pumpAndSettle();

      expect(find.byType(JoinTourneeScreen), findsOneWidget);
      expect(find.byType(CreateTourneeScreen), findsNothing);
    },
  );

  testWidgets(
    'should let a free number be created once the taken one is changed',
    (tester) async {
      directory.taken.add((csVillefranche.key, number49));
      await open(tester);
      await fillIn(tester);

      await tester.enterText(find.byKey(const Key('create.number')), '48');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create.taken')), findsNothing);
      expect(isEnabled(tester, createButton), isTrue);
    },
  );

  testWidgets('should say nothing exists when the number is free', (
    tester,
  ) async {
    await open(tester);

    await fillIn(tester);

    expect(find.byKey(const Key('create.taken')), findsNothing);
    expect(find.byKey(const Key('create.joinWithCode')), findsNothing);
    expect(isEnabled(tester, createButton), isTrue);
  });

  testWidgets(
    'should show the code and its QR code once created, then open the '
    'start screen on the new tournée',
    (tester) async {
      await open(tester);
      await fillIn(tester);

      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Tournée 49 · CS Villefranche est prête. Montrez ce code à l'équipe.",
        ),
        findsOneWidget,
      );
      expect(find.text('234-567'), findsOneWidget);
      expect(
        find.bySemanticsLabel('QR code de la tournée, code 234-567'),
        findsOneWidget,
      );
      expect(tournees.added.single.number, number49);

      final continueButton = find.byKey(const Key('create.continue'));
      // Built only once scrolled to: the code card fills the screen.
      await tester.scrollUntilVisible(
        continueButton,
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    },
  );

  testWidgets('should say the number is no tournée number', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('create.number')), '0');
    await tester.pumpAndSettle();

    expect(find.text('Un numéro de 1 à 9999.'), findsOneWidget);
  });
}
