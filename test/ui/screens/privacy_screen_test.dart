import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/fake_url_launcher.dart';
import '../support/large_text.dart';
import '../support/test_app.dart';

const _url =
    'https://github.com/emmanuel-h/Tournee-Calendriers/blob/main/PRIVACY.md';

void main() {
  Future<FakeUrlLauncher> pumpPrivacy(
    WidgetTester tester, {
    bool opens = true,
    bool fails = false,
  }) async {
    final browser = FakeUrlLauncher.install(opens: opens, fails: fails);
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
    // Writing to the developer from Paramètres gives away an address (#118).
    expect(
      arb['privacyAccountBody'],
      endsWith(
        'Si vous écrivez au développeur depuis Paramètres, votre messagerie '
        'lui envoie votre adresse e-mail\u00a0; elle sert seulement à vous '
        'répondre.',
      ),
    );
    // French typography: a non-breaking space before « : ».
    expect(arb['privacyDataBody'], contains('secteur : les numéros'));
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

    // The policy is longer than the test screen: scroll to the row.
    await tester.ensureVisible(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();

    expect(browser.opened, [(_url, PreferredLaunchMode.externalApplication)]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('should give the address when no browser opens the policy', (
    tester,
  ) async {
    final browser = await pumpPrivacy(tester, opens: false);

    // The policy is longer than the test screen: scroll to the row.
    await tester.ensureVisible(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();
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

    // The policy is longer than the test screen: scroll to the row.
    await tester.ensureVisible(find.byKey(const Key('privacy.online')));
    await tester.pumpAndSettle();
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
