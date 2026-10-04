import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/app.dart';

void main() {
  testWidgets('should show the French title when the app starts', (
    tester,
  ) async {
    // Widgets that read providers need a ProviderScope above them, exactly as
    // bootstrap provides in the real app.
    await tester.pumpWidget(const ProviderScope(child: TourneeApp()));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Tournée des calendriers'),
      ),
      findsOneWidget,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Tournée des calendriers');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
