import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/large_text.dart';
import '../support/test_app.dart';

/// The phone's browser, as url_launcher reaches it: it records what it was
/// asked to open and answers [opens], or throws when [fails].
///
/// `MockPlatformInterfaceMixin` lets a test class stand in for the plugin
/// (`UrlLauncherPlatform.instance = …`), which otherwise only accepts a
/// subclass registered by the plugin itself.
final class _FakeBrowser extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeBrowser({this.opens = true, this.fails = false});

  final bool opens;
  final bool fails;
  final opened = <(String, PreferredLaunchMode)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add((url, options.mode));
    if (fails) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    return opens;
  }
}

const _url =
    'https://github.com/emmanuel-h/Tournee-Calendriers/blob/main/PRIVACY.md';

void main() {
  final realBrowser = UrlLauncherPlatform.instance;
  tearDown(() => UrlLauncherPlatform.instance = realBrowser);

  Future<_FakeBrowser> pumpPrivacy(
    WidgetTester tester, {
    bool opens = true,
    bool fails = false,
  }) async {
    final browser = _FakeBrowser(opens: opens, fails: fails);
    UrlLauncherPlatform.instance = browser;
    await tester.pumpWidget(testApp(const PrivacyScreen()));
    await tester.scrollUntilVisible(
      find.byKey(const Key('privacy.online')),
      200,
    );
    return browser;
  }

  test('should show the five sections of PRIVACY.md word for word', () {
    // The page and the public policy are one text (#79, #36): a change to
    // one without the other fails here.
    final policy = File('PRIVACY.md').readAsStringSync();
    final sections = {
      for (final match in RegExp(
        r'^## (.+)\n\n(.+)\n',
        multiLine: true,
      ).allMatches(policy))
        match.group(1)!: match.group(2)!,
    };
    final arb = jsonDecode(
      File('lib/ui/l10n/app_fr.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(arb['privacyAccountBody'], sections['Compte']);
    expect(arb['privacyDataBody'], sections['Données enregistrées']);
    expect(arb['privacyLocationBody'], sections['Position']);
    expect(arb['privacyHostingBody'], sections['Hébergement']);
    expect(arb['privacyDeletionBody'], sections['Suppression']);
    // French typography: a non-breaking space before « : ».
    expect(arb['privacyDataBody'], contains('tournée : les numéros'));
  });

  testWidgets('should show the online policy row with its ↗ and label', (
    tester,
  ) async {
    await pumpPrivacy(tester);

    final row = find.byKey(const Key('privacy.online'));
    expect(
      find.descendant(
        of: row,
        matching: find.text('Politique complète en ligne'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Politique complète en ligne, s\'ouvre dans le navigateur',
      ),
      findsOneWidget,
    );
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
  });

  testWidgets('should open the policy in the browser when the row is tapped', (
    tester,
  ) async {
    final browser = await pumpPrivacy(tester);

    await tester.tap(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();

    expect(browser.opened, [(_url, PreferredLaunchMode.externalApplication)]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('should give the address when no browser opens the policy', (
    tester,
  ) async {
    final browser = await pumpPrivacy(tester, opens: false);

    await tester.tap(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();

    expect(browser.opened, hasLength(1));
    expect(
      find.text(
        'Impossible d\'ouvrir le navigateur. La politique est à '
        'l\'adresse $_url',
      ),
      findsOneWidget,
    );
  });

  testWidgets('should give the address when the browser plugin fails', (
    tester,
  ) async {
    await pumpPrivacy(tester, fails: true);

    await tester.tap(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();

    expect(find.textContaining(_url), findsOneWidget);
  });

  group('at 200 %', () {
    setUpAll(loadAppFonts);

    testWidgets('should keep the link row whole and accessible', (
      tester,
    ) async {
      useLargeText(tester);
      await pumpPrivacy(tester);

      await expectAccessibleControls(tester);
    });
  });
}
