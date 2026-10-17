import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/start_or_home.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_pending_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/welcome_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/navigation.dart';

void main() {
  late FakeTourneeDirectory directory;
  late FakeMyTourneesStore store;

  /// Starts the app on Julie's phone, signed in, her name kept, holding
  /// [mine]; it opens where a real launch would.
  Future<void> launch(WidgetTester tester, MyTournees mine) async {
    store = FakeMyTourneesStore(mine);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          tourneeDirectory: directory,
          myTournees: store,
          settings: FakePhoneSettings(memberName: nameOf('Julie')),
          account: FakeMemberAccount(signedInMember: julieId),
          chooseLaunch: true,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    directory = FakeTourneeDirectory()
      ..previews[firstCode] = JoinPreview(
        code: firstCode,
        tourneeId: tourneeId,
        number: number49,
        centre: csVillefranche,
        campaign: campaign2026,
      );
  });

  final request49 = summaryOf('t49', 49, status: MemberStatus.pending);

  testWidgets(
    'should show the tournée of the code typed, then wait for the answer '
    'once the request is sent',
    (tester) async {
      await launch(tester, MyTournees.none.remember(tournee12));
      unawaitedPush(
        GoRouter.of(tester.element(find.byType(StartOrHome))),
        AppRoutes.join,
      );
      await tester.pumpAndSettle();
      final request = find.byKey(const Key('join.request'));
      expect(isEnabled(tester, request), isFalse);

      await tester.enterText(find.byKey(const Key('join.first')), 'k7p');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('join.second')), '2qx');
      await tester.pumpAndSettle();

      expect(find.text('Tournée 49 · CS Villefranche'), findsOneWidget);
      expect(find.text('Campagne 2026'), findsOneWidget);
      expect(isEnabled(tester, request), isTrue);

      await tester.tap(request);
      await tester.pumpAndSettle();

      expect(find.byType(JoinPendingScreen), findsOneWidget);
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.bySemanticsLabel('Demande en attente'), findsOneWidget);
      expect(directory.sent.single.$2.id, julieId);
      expect(store.myTournees.find(tourneeId), request49);
    },
  );

  testWidgets('should say a character no code has is typed', (tester) async {
    await launch(tester, MyTournees.none.remember(tournee12));
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(StartOrHome))),
      AppRoutes.join,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('join.first')), 'K0P');
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Un code n'a que des lettres et des chiffres, sans 0, O, 1, I ni L.",
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'should fill both boxes when a whole code is typed in the first',
    (tester) async {
      await launch(tester, MyTournees.none.remember(tournee12));
      unawaitedPush(
        GoRouter.of(tester.element(find.byType(StartOrHome))),
        AppRoutes.join,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('join.first')), 'K0P');
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('join.first')), 'k7p-2qx');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'K7P'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2QX'), findsOneWidget);
      expect(find.text('Tournée 49 · CS Villefranche'), findsOneWidget);
    },
  );

  testWidgets(
    'should keep three upper-case characters in the second box whatever '
    'more is typed',
    (tester) async {
      await launch(tester, MyTournees.none.remember(tournee12));
      unawaitedPush(
        GoRouter.of(tester.element(find.byType(StartOrHome))),
        AppRoutes.join,
      );
      await tester.pumpAndSettle();
      final second = find.byKey(const Key('join.second'));
      await tester.enterText(second, '2QX');
      await tester.pumpAndSettle();

      await tester.enterText(second, '2QXz');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(second).controller!.text, '2QX');
    },
  );

  group('« Demande envoyée »', () {
    testWidgets('should open the start screen on the tournée once accepted', (
      tester,
    ) async {
      await launch(tester, MyTournees.none.remember(request49));
      expect(find.byType(JoinPendingScreen), findsOneWidget);

      directory.answer(tourneeId, MemberStatus.active);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    });

    testWidgets('should say refused and go back to « Bienvenue »', (
      tester,
    ) async {
      await launch(tester, MyTournees.none.remember(request49));

      directory.answer(tourneeId, null);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Demande refusée'), findsOneWidget);
    });

    testWidgets('should withdraw the request and go back to « Bienvenue »', (
      tester,
    ) async {
      await launch(tester, MyTournees.none.remember(request49));

      await tester.tap(find.byKey(const Key('pending.cancel')));
      await tester.pumpAndSettle();

      expect(directory.cancelled, [(tourneeId, julieId)]);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Demande refusée'), findsNothing);
    });

    testWidgets(
      'should offer the way back to the start screen when the phone has one',
      (tester) async {
        await launch(
          tester,
          valueOf(
            MyTournees.none
                .remember(tournee12)
                .remember(request49)
                .open(tournee12.id),
          ),
        );
        GoRouter.of(tester.element(find.byType(StartOrHome)))
            .go(AppRoutes.joinPendingOf(tourneeId));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('pending.back')));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Tournée 12 · 2026'), findsOneWidget);
      },
    );
  });
}
