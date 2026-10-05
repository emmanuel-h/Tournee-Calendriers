import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/save_failed_alert.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late SaveFailedAlert alert;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    alert = SaveFailedAlert(navigatorKey);
  });

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(body: Text('Rue des Lilas')),
    ),
  );

  testWidgets('should say the change was not kept when shown', (tester) async {
    await pumpScreen(tester);

    alert.show();
    await tester.pumpAndSettle();

    expect(find.text('Enregistrement impossible'), findsOneWidget);
    expect(
      find.text(
        "Le téléphone n'a pas pu enregistrer le dernier changement\u00a0: sa "
        'mémoire est peut-être pleine. Libérez de la place avant de fermer '
        "l'application.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('should show one dialog when several saves fail in a row', (
    tester,
  ) async {
    await pumpScreen(tester);

    alert.show();
    alert.show();
    await tester.pumpAndSettle();
    alert.show();
    await tester.pumpAndSettle();

    expect(find.text('Enregistrement impossible'), findsOneWidget);
  });

  testWidgets('should close on OK and show again at the next failure', (
    tester,
  ) async {
    await pumpScreen(tester);
    alert.show();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('saveFailed.ok')));
    await tester.pumpAndSettle();

    expect(find.text('Enregistrement impossible'), findsNothing);

    alert.show();
    await tester.pumpAndSettle();

    expect(find.text('Enregistrement impossible'), findsOneWidget);
  });

  testWidgets('should show nothing when no screen is up yet', (tester) async {
    alert.show();

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enregistrement impossible'), findsNothing);
  });
}
