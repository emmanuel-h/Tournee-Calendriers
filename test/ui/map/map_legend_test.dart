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

  testWidgets('should draw « libre » as dark dashes as wide as the other '
      'samples, with no casing', (tester) async {
    await tester.pumpWidget(testApp(const MapLegend(houses: false)));

    // Dash 6, gap 4 across the 22 dp sample from 2 to 20: two dashes, and
    // no other line (no white casing on the legend's white ground).
    expect(
      sample(tester, 'libre'),
      paints
        ..line(
          p1: const Offset(2, 4),
          p2: const Offset(8, 4),
          color: AppColors.light.mapStreetFree,
          strokeWidth: 6,
        )
        ..line(
          p1: const Offset(12, 4),
          p2: const Offset(18, 4),
          color: AppColors.light.mapStreetFree,
          strokeWidth: 6,
        ),
    );
    expect(sample(tester, 'libre'), paintsExactlyCountTimes(#drawLine, 2));
  });

  testWidgets('should draw a taken street as one solid line', (tester) async {
    await tester.pumpWidget(testApp(const MapLegend(houses: false)));

    expect(
      sample(tester, 'à faire'),
      paints..line(
        p1: const Offset(2, 4),
        p2: const Offset(20, 4),
        color: AppColors.light.mapStreetToDo,
        strokeWidth: 6,
      ),
    );
    expect(sample(tester, 'à faire'), paintsExactlyCountTimes(#drawLine, 1));
  });
}
