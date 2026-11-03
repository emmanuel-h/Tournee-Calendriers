import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/map/map_legend.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

import '../support/test_app.dart';

void main() {
  /// The line sample drawn before [word] in the legend.
  RenderObject sample(WidgetTester tester, String word) => tester.renderObject(
    find.descendant(
      of: find.ancestor(of: find.text(word), matching: find.byType(Row)).first,
      matching: find.byType(CustomPaint),
    ),
  );

  testWidgets('should show the three street samples, and no « libre » '
      '(PLAN §5.14)', (tester) async {
    await tester.pumpWidget(testApp(const MapLegend(houses: false)));

    for (final word in ['faite', 'en partie', 'à faire']) {
      expect(find.text(word), findsOneWidget);
    }
    expect(find.text('libre'), findsNothing);
  });

  testWidgets('should draw each street as one solid line in its '
      'colour', (tester) async {
    await tester.pumpWidget(testApp(const MapLegend(houses: false)));

    for (final (word, color) in [
      ('faite', AppColors.light.mapStreetDone),
      ('en partie', AppColors.light.mapStreetPartial),
      ('à faire', AppColors.light.mapStreetToDo),
    ]) {
      expect(
        sample(tester, word),
        paints..line(
          p1: const Offset(2, 4),
          p2: const Offset(20, 4),
          color: color,
          strokeWidth: 6,
        ),
      );
      expect(sample(tester, word), paintsExactlyCountTimes(#drawLine, 1));
    }
  });

  testWidgets('should draw the light map colours when the legend is '
      'dark', (tester) async {
    await tester.pumpWidget(
      testApp(const MapLegend(houses: false), colors: AppColors.dark),
    );

    expect(
      sample(tester, 'à faire'),
      paints..line(color: AppColors.dark.mapStreetToDo, strokeWidth: 6),
    );
    expect(sample(tester, 'à faire'), paintsExactlyCountTimes(#drawLine, 1));
  });
}
