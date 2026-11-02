import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/start_or_home.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_pending_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/welcome_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

void main() {
  late FakeSectorDirectory directory;
  late FakeMySectorsStore store;

  /// Starts the app on Julie's phone, signed in, her name kept, holding
  /// [mine]; it opens where a real launch would.
  Future<void> launch(WidgetTester tester, MySectors mine) async {
    store = FakeMySectorsStore(mine);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          sectorDirectory: directory,
          mySectors: store,
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
    directory = FakeSectorDirectory()
      ..previews[firstCode] = JoinPreview(
        code: firstCode,
        sectorId: sectorId,
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
      await launch(tester, MySectors.none.remember(sector12));
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

      expect(find.text('Secteur 49 · CS Villefranche'), findsOneWidget);
      expect(find.text('Campagne 2026'), findsOneWidget);
      expect(isEnabled(tester, request), isTrue);

      await tester.tap(request);
      await tester.pumpAndSettle();

      expect(find.byType(JoinPendingScreen), findsOneWidget);
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.bySemanticsLabel('Demande en attente'), findsOneWidget);
      expect(directory.sent.single.$2.id, julieId);
      expect(store.mySectors.find(sectorId), request49);
    },
  );

  testWidgets('should say a character no code has is typed', (tester) async {
    await launch(tester, MySectors.none.remember(sector12));
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
      await launch(tester, MySectors.none.remember(sector12));
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
      expect(find.text('Secteur 49 · CS Villefranche'), findsOneWidget);
    },
  );

  testWidgets(
    'should keep three upper-case characters in the second box whatever '
    'more is typed',
    (tester) async {
      await launch(tester, MySectors.none.remember(sector12));
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
      await launch(tester, MySectors.none.remember(request49));
      expect(find.byType(JoinPendingScreen), findsOneWidget);

      directory.answer(sectorId, MemberStatus.active);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Secteur 49 · 2026'), findsOneWidget);
    });

    testWidgets('should say refused and go back to « Bienvenue »', (
      tester,
    ) async {
      await launch(tester, MySectors.none.remember(request49));

      directory.answer(sectorId, null);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Demande refusée'), findsOneWidget);
    });

    testWidgets('should withdraw the request and go back to « Bienvenue »', (
      tester,
    ) async {
      await launch(tester, MySectors.none.remember(request49));

      await tester.tap(find.byKey(const Key('pending.cancel')));
      await tester.pumpAndSettle();

      expect(directory.cancelled, [(sectorId, julieId)]);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Demande refusée'), findsNothing);
    });

    testWidgets(
      'should offer the way back to the start screen when the phone has one',
      (tester) async {
        await launch(
          tester,
          valueOf(
            MySectors.none
                .remember(sector12)
                .remember(request49)
                .open(sector12.id),
          ),
        );
        GoRouter.of(tester.element(find.byType(StartOrHome)))
            .go(AppRoutes.joinPendingOf(sectorId));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('pending.back')));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Secteur 12 · 2026'), findsOneWidget);
      },
    );
  });

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    testWidgets('should show « Rejoindre », then the wait, with no overflow '
        'when the text is twice as large', (tester) async {
      useLargeText(tester);
      await launch(tester, MySectors.none.remember(sector12));
      unawaitedPush(
        GoRouter.of(tester.element(find.byType(StartOrHome))),
        AppRoutes.join,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('join.first')), 'k7p');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('join.second')), '2qx');
      await tester.pumpAndSettle();
      expect(find.text('Secteur 49 · CS Villefranche'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(const Key('join.request')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('join.request')));
      await tester.pumpAndSettle();

      expect(find.byType(JoinPendingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await launch(tester, MySectors.none.remember(sector12));
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(StartOrHome))),
      AppRoutes.join,
    );
    await tester.pumpAndSettle();

    await expectAccessibleControls(tester);
  });
}
