import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';

import '../support/large_text.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final (name, button) in [
    (
      'a primary button',
      PrimaryButton(label: 'Rejoindre un secteur', onPressed: () {}),
    ),
    (
      'a secondary button',
      SecondaryButton(label: 'Repassé, toujours personne', onPressed: () {}),
    ),
  ]) {
    testWidgets('should keep 24 dp each side of the label of $name when the '
        'text is twice as large', (tester) async {
      useLargeText(tester);
      await tester.pumpWidget(testApp(Center(child: button)));

      final outline = tester.getRect(find.byWidget(button));
      final label = tester.getRect(find.byType(Text));

      expect(label.left - outline.left, greaterThanOrEqualTo(24));
      expect(outline.right - label.right, greaterThanOrEqualTo(24));
      expect(tester.takeException(), isNull);
    });
  }
}
