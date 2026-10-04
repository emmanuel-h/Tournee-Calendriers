// Instrumented suite: end-to-end flows run inside the real app on an Android
// emulator or phone (`flutter test integration_test -d <device>`).
//
// Unlike `test/`, these tests start the actual app with the real
// composition root, so they catch what unit and widget tests cannot: wiring,
// platform plugins, startup. The suite stays small on purpose (≤ 10 tests).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tournee_calendriers/main.dart' as app;

void main() {
  // Connects the test to the device so results are reported back to
  // `flutter test`.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('should show the French title when the app starts', (
    tester,
  ) async {
    // The app reads its storage before the first frame: wait for it.
    await app.main();
    // Waits until the first frames are drawn and no animation is running.
    await tester.pumpAndSettle();

    expect(find.text('Tournée des calendriers'), findsOneWidget);
  });

  testWidgets(
    'should open the component gallery when the app is a debug build',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home.gallery')));
      await tester.pumpAndSettle();

      expect(find.text('Composants'), findsOneWidget);
      expect(find.bySemanticsLabel('Numéro 3bis, personne'), findsOneWidget);
    },
  );
}
