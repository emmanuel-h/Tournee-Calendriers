import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/home/no_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show nameOf;
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../support/app_overrides.dart';
import '../support/fake_map_view.dart';
import '../support/large_text.dart';

void main() {
  late FakePhoneSettings settings;

  /// Léa's phone, which knows the 12 but has no secteur open, on the
  /// mockups' 390 × 844 dp screen unless [phoneSize] is false. An admin's
  /// when [admin] says so; named Léa, or nothing with [unnamed].
  Future<void> pumpStart(
    WidgetTester tester, {
    bool admin = false,
    bool unnamed = false,
    bool phoneSize = true,
  }) async {
    if (phoneSize) {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }
    settings = FakePhoneSettings(memberName: unnamed ? null : nameOf('Léa'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: FakeMySectorsStore(MySectors.none.remember(sector12)),
          settings: settings,
          admins: FakeAdminStatus(phoneIsAdmin: admin),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  final join = find.byKey(const Key('noSector.join'));
  final create = find.byKey(const Key('noSector.create'));

  testWidgets('should show the map with no street, no legend and no team, '
      'and say no secteur is open', (tester) async {
    await pumpStart(tester);

    expect(find.byType(NoSectorScreen), findsOneWidget);
    expect(find.text('Tournée des calendriers'), findsOneWidget);
    expect(find.text('Aucun secteur ouvert'), findsOneWidget);
    expect(
      find.text(
        "Rejoignez le secteur de votre équipe avec le code qu'on vous a "
        'donné.',
      ),
      findsOneWidget,
    );
    final map = shownMap(tester);
    expect(map.layers.lines, isEmpty);
    expect(map.layers.dots, isEmpty);
    expect(map.area, isNull);
    expect(find.byKey(const Key('map.legend')), findsNothing);
    expect(find.byKey(const Key('home.team')), findsNothing);
    expect(find.byKey(const Key('home.settings')), findsOneWidget);
  });

  testWidgets('should keep the map clear of the panel', (tester) async {
    await pumpStart(tester);

    final panel = find.byKey(const Key('noSector.panel'));
    expect(shownMap(tester).padding.bottom, tester.getSize(panel).height);
    expect(shownMap(tester).padding.bottom, greaterThan(0));
  });

  testWidgets('should offer only « Rejoindre un secteur », in red, to a '
      'member who is not an admin', (tester) async {
    await pumpStart(tester);

    expect(
      find.descendant(of: join, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    expect(find.text('Rejoindre un secteur'), findsOneWidget);
    expect(create, findsNothing);
    expect(find.text('Créer un secteur'), findsNothing);
  });

  testWidgets('should offer « Créer un secteur », outlined, under '
      '« Rejoindre » to an admin', (tester) async {
    await pumpStart(tester, admin: true);

    expect(
      find.descendant(of: create, matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(create).dy,
      greaterThan(tester.getTopLeft(join).dy),
    );
  });

  testWidgets('should open « Rejoindre un secteur »', (tester) async {
    await pumpStart(tester);

    await tester.tap(join);
    await tester.pumpAndSettle();

    expect(find.byType(JoinSectorScreen), findsOneWidget);
  });

  testWidgets('should open « Nouveau secteur » for an admin', (tester) async {
    await pumpStart(tester, admin: true);

    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.byType(CreateSectorScreen), findsOneWidget);
  });

  testWidgets('should ask the name first when the phone has none, then open '
      '« Rejoindre un secteur »', (tester) async {
    await pumpStart(tester, unnamed: true);

    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.byType(NameSheet), findsOneWidget);
    expect(find.byType(JoinSectorScreen), findsNothing);
    await tester.enterText(find.byKey(const Key('name.field')), 'Léa');
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    expect(settings.names, [nameOf('Léa')]);
    expect(find.byType(JoinSectorScreen), findsOneWidget);
  });

  testWidgets('should open « Mes secteurs » from the app\'s name', (
    tester,
  ) async {
    await pumpStart(tester);

    await tester.tap(find.byKey(const Key('home.appTitle')));
    await tester.pumpAndSettle();

    expect(find.byType(MySectorsSheet), findsOneWidget);
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpStart(tester, admin: true);

    await expectAccessibleControls(tester);
  });

  group('large text', () {
    setUpAll(loadAppFonts);

    testWidgets('should show the panel with no overflow when the text is '
        'twice as large', (tester) async {
      useLargeText(tester);

      await pumpStart(tester, admin: true, phoneSize: false);

      expect(create, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
