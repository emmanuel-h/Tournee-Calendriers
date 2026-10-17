import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_pending_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/welcome_screen.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart' show nameOf;
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/clipboard.dart';

/// The phone's uid, as Firebase makes them.
final phoneUid = MemberId('x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');

void main() {
  late FakePhoneSettings settings;

  /// Launches the app on a phone holding [mine], the phone [streets] and
  /// the name [name], letting it choose where to open. The phone is an
  /// admin's when [admin] says so; it has [account] (an account by
  /// default).
  Future<void> launch(
    WidgetTester tester, {
    MyTournees mine = MyTournees.none,
    FakeStreetRepository? streets,
    MemberName? name,
    bool admin = false,
    FakeMemberAccount? account,
  }) async {
    settings = FakePhoneSettings(memberName: name);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: FakeMyTourneesStore(mine),
          phoneStreets: streets,
          settings: settings,
          account: account ?? FakeMemberAccount(signedInMember: phoneUid),
          admins: FakeAdminStatus(phoneIsAdmin: admin),
          chooseLaunch: true,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  final create = find.byKey(const Key('welcome.create'));
  final join = find.byKey(const Key('welcome.join'));
  final name = find.byKey(const Key('welcome.name'));

  group('where the app opens', () {
    testWidgets('should open « Bienvenue » on a phone holding nothing', (
      tester,
    ) async {
      await launch(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Tournée des calendriers'), findsOneWidget);
      expect(find.text('Visible par votre équipe.'), findsOneWidget);
    });

    testWidgets(
      'should open « Mes rues » on a phone holding streets of its own',
      (tester) async {
        await launch(tester, streets: FakeStreetRepository([lilas]));

        expect(find.byType(StartScreen), findsOneWidget);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
    );

    testWidgets('should open the start screen on a phone with a tournée open', (
      tester,
    ) async {
      await launch(
        tester,
        mine: valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    });

    testWidgets(
      'should open « Demande envoyée » on a phone holding only a request',
      (tester) async {
        await launch(
          tester,
          mine: MyTournees.none.remember(
            summaryOf('t49', 49, status: MemberStatus.pending),
          ),
        );

        expect(find.byType(JoinPendingScreen), findsOneWidget);
        expect(find.text('Tournée 49 · CS Villefranche'), findsOneWidget);
        expect(find.byKey(const Key('pending.back')), findsNothing);
      },
    );
  });

  group('the name', () {
    testWidgets('should keep both buttons disabled until a name is typed', (
      tester,
    ) async {
      await launch(tester, admin: true);

      expect(isEnabled(tester, create), isFalse);
      expect(isEnabled(tester, join), isFalse);

      await tester.enterText(name, '   ');
      await tester.pump();
      expect(isEnabled(tester, create), isFalse);

      await tester.enterText(name, 'Léa');
      await tester.pump();
      expect(isEnabled(tester, create), isTrue);
      expect(isEnabled(tester, join), isTrue);
    });

    testWidgets('should say a name is too long and keep the buttons disabled', (
      tester,
    ) async {
      await launch(tester, admin: true);

      await tester.enterText(name, 'A' * 31);
      await tester.pump();

      expect(find.text('Prénom limité à 30 caractères.'), findsOneWidget);
      expect(find.text('Visible par votre équipe.'), findsNothing);
      expect(isEnabled(tester, create), isFalse);
    });

    testWidgets('should keep the name and open « Nouvelle tournée »', (
      tester,
    ) async {
      await launch(tester, admin: true);
      await tester.enterText(name, ' Léa ');
      await tester.pump();

      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(settings.names, [nameOf('Léa')]);
      expect(find.byType(CreateTourneeScreen), findsOneWidget);
    });

    testWidgets('should keep the name and open « Rejoindre une tournée »', (
      tester,
    ) async {
      await launch(tester);
      await tester.enterText(name, 'Léa');
      await tester.pump();

      await tester.tap(join);
      await tester.pumpAndSettle();

      expect(settings.names, [nameOf('Léa')]);
      expect(find.byType(JoinTourneeScreen), findsOneWidget);
    });

    testWidgets('should start from the name the phone keeps', (tester) async {
      await launch(tester, name: nameOf('Manu'));

      expect(find.widgetWithText(TextField, 'Manu'), findsOneWidget);
      expect(isEnabled(tester, join), isTrue);
    });
  });

  group('admins (PLAN §5.12)', () {
    testWidgets('should offer only « Rejoindre une tournée », in red, to a '
        'phone that is not an admin\'s', (tester) async {
      await launch(tester, name: nameOf('Léa'));

      expect(create, findsNothing);
      expect(
        find.descendant(of: join, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
    });

    testWidgets('should offer « Créer une tournée » to an admin, with '
        '« Rejoindre » under it', (tester) async {
      await launch(tester, name: nameOf('Manu'), admin: true);

      expect(create, findsOneWidget);
      expect(
        find.descendant(of: join, matching: find.byType(OutlinedButton)),
        findsOneWidget,
      );
    });

    testWidgets('should show the whole device id, and copy it', (tester) async {
      final clipboard = FakeClipboard.install(tester);
      await launch(tester);

      expect(find.text('Identifiant de l\'appareil'), findsOneWidget);
      expect(find.text('x7FqA1b2C3d4E5f6G7h8I9j0k9kP2'), findsOneWidget);

      await tester.tap(find.byTooltip('Copier l\'identifiant de l\'appareil'));
      await tester.pump();

      expect(clipboard.text, 'x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');
      expect(find.text('Identifiant copié'), findsOneWidget);
    });

    testWidgets('should sign in when it opens, then show the device id', (
      tester,
    ) async {
      final account = FakeMemberAccount(nextMember: phoneUid);
      await launch(tester, account: account);

      expect(account.signInCalls, greaterThanOrEqualTo(1));
      expect(find.byKey(const Key('welcome.deviceId')), findsOneWidget);
    });

    testWidgets('should show no device id while the phone has no account', (
      tester,
    ) async {
      await launch(tester, account: FakeMemberAccount());

      expect(find.byKey(const Key('welcome.deviceId')), findsNothing);
      expect(find.byKey(const Key('welcome.copyDeviceId')), findsNothing);
    });
  });
}
