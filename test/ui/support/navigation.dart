import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Opens [location] on top of the current screen without waiting: `push`
/// returns a `Future` that ends only when the pushed screen is closed.
void unawaitedPush(GoRouter router, String location) {
  router.push<void>(location).ignore();
}

/// Opens « Ajouter des rues » from Accueil as a member does (PLAN §5.14):
/// the title (Secteur), then « + Ajouter des rues » in Secteur, scrolled to.
Future<void> openAddStreets(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home.sector')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('team.addStreets')),
    100,
    scrollable: find.descendant(
      of: find.byKey(const Key('team.list')),
      matching: find.byType(Scrollable),
    ),
  );
  // Built is not yet on screen: the row may still sit under the pinned
  // footer, so it is brought fully into the list's view.
  await tester.ensureVisible(find.byKey(const Key('team.addStreets')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('team.addStreets')));
  await tester.pumpAndSettle();
}
