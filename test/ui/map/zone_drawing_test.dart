// Drawing a zone with a finger over the map of « Ajouter des rues » (PLAN
// §5.14, PickZone mockup).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/map/zone_drawing.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';

void main() {
  late List<Rect> drawn;
  late List<String> tapped;

  setUp(() {
    drawn = [];
    tapped = [];
  });

  /// A 400 × 600 area standing for the map, which counts its taps.
  Future<void> pump(WidgetTester tester, {bool enabled = true, Rect? shown}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppColors.light),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: ZoneDrawing(
                enabled: enabled,
                onDrawn: drawn.add,
                zoneOnScreen: () => shown,
                child: GestureDetector(
                  onTap: () => tapped.add('map'),
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );

  Rect? painted(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('zoneDrawing.paint')),
                  )
                  .painter!
              as ZonePainter)
          .zone;

  testWidgets('should hand over the rectangle drawn, painting it meanwhile', (
    tester,
  ) async {
    await pump(tester);

    final finger = await tester.startGesture(const Offset(100, 100));
    await finger.moveTo(const Offset(300, 250));
    await tester.pump();

    expect(painted(tester), const Rect.fromLTRB(100, 100, 300, 250));
    expect(drawn, isEmpty);

    await finger.up();
    await tester.pump();

    expect(
      drawn.single,
      rectMoreOrLessEquals(const Rect.fromLTRB(100, 100, 300, 250)),
    );
    expect(painted(tester), isNull);
  });

  testWidgets('should take a drag up and to the left the right way round', (
    tester,
  ) async {
    await pump(tester);

    await tester.dragFrom(const Offset(300, 250), const Offset(-200, -150));

    expect(
      drawn.single,
      rectMoreOrLessEquals(const Rect.fromLTRB(100, 100, 300, 250)),
    );
  });

  testWidgets('should draw nothing for a drag shorter than 16 on a side', (
    tester,
  ) async {
    await pump(tester);

    await tester.dragFrom(const Offset(100, 100), const Offset(200, 15));
    await tester.dragFrom(const Offset(100, 100), const Offset(15, 200));

    expect(drawn, isEmpty);
  });

  testWidgets('should draw a zone of 16 on each side', (tester) async {
    await pump(tester);

    await tester.dragFrom(const Offset(100, 100), const Offset(16, 16));

    expect(
      drawn.single,
      rectMoreOrLessEquals(const Rect.fromLTRB(100, 100, 116, 116)),
    );
  });

  testWidgets('should draw nothing while off, the map getting the taps', (
    tester,
  ) async {
    await pump(tester, enabled: false);

    await tester.dragFrom(const Offset(100, 100), const Offset(200, 150));
    await tester.tapAt(const Offset(50, 50));

    expect(drawn, isEmpty);
    expect(tapped, ['map']);
  });

  testWidgets('should drop the drawing when a second finger pinches', (
    tester,
  ) async {
    await pump(tester);

    final first = await tester.startGesture(const Offset(100, 100));
    await first.moveTo(const Offset(200, 200));
    final second = await tester.startGesture(
      const Offset(300, 300),
      pointer: 2,
    );
    await tester.pump();

    expect(painted(tester), isNull);
    await second.up();
    await first.up();
    expect(drawn, isEmpty);
  });

  testWidgets('should draw again once the pinch is over', (tester) async {
    await pump(tester);
    final first = await tester.startGesture(const Offset(100, 100));
    final second = await tester.startGesture(
      const Offset(300, 300),
      pointer: 2,
    );
    await second.up();
    await first.up();

    await tester.dragFrom(const Offset(100, 100), const Offset(50, 50));

    expect(
      drawn.single,
      rectMoreOrLessEquals(const Rect.fromLTRB(100, 100, 150, 150)),
    );
  });

  testWidgets('should drop the drawing when the pointer is cancelled', (
    tester,
  ) async {
    await pump(tester);

    final finger = await tester.startGesture(const Offset(100, 100));
    await finger.moveTo(const Offset(200, 200));
    await finger.cancel();
    await tester.pump();

    expect(painted(tester), isNull);
    expect(drawn, isEmpty);
  });

  group('the handle', () {
    const shown = Rect.fromLTRB(100, 100, 300, 250);

    testWidgets('should resize the zone from its opposite corner', (
      tester,
    ) async {
      await pump(tester, shown: shown);

      // 20 from the handle: within reach.
      await tester.dragFrom(const Offset(312, 266), const Offset(40, 50));

      expect(
        drawn.single,
        rectMoreOrLessEquals(const Rect.fromLTRB(100, 100, 352, 316)),
      );
    });

    testWidgets('should draw a new zone from a finger beyond its reach', (
      tester,
    ) async {
      await pump(tester, shown: shown);

      // 25 from the handle.
      await tester.dragFrom(const Offset(315, 270), const Offset(40, 50));

      expect(
        drawn.single,
        rectMoreOrLessEquals(const Rect.fromLTRB(315, 270, 355, 320)),
      );
    });
  });

  testWidgets('should stop drawing when turned off under the finger', (
    tester,
  ) async {
    await pump(tester);
    final finger = await tester.startGesture(const Offset(100, 100));
    await finger.moveTo(const Offset(200, 200));

    await pump(tester, enabled: false);
    await finger.up();

    expect(painted(tester), isNull);
    expect(drawn, isEmpty);
  });

  testWidgets('should repaint only when the zone or the colours change', (
    tester,
  ) async {
    await pump(tester);
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('zoneDrawing.paint')))
                .painter!
            as ZonePainter;

    expect(painter.shouldRepaint(painter), isFalse);
    expect(
      painter.shouldRepaint(
        ZonePainter(zone: Rect.zero, colors: painter.colors),
      ),
      isTrue,
    );
  });
}
