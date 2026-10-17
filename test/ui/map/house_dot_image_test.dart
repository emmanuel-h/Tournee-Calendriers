import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/ui/map/house_dot_image.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

const _colors = AppColors.light;

/// A decoded picture, to read its pixels.
final class _Picture {
  _Picture(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  Color at(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      rgba.getUint8(offset + 3),
      rgba.getUint8(offset),
      rgba.getUint8(offset + 1),
      rgba.getUint8(offset + 2),
    );
  }
}

/// Draws [status]'s dot at [ratio] and decodes it. Image work needs real
/// async (`runAsync`): the fake clock of widget tests never lets it finish.
Future<_Picture> _draw(
  WidgetTester tester,
  HouseDotStatus status, {
  double ratio = 4,
}) async => (await tester.runAsync(() async {
  final png = await houseDotPng(HouseDotLook.of(status, _colors), ratio);
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final rgba = await image.toByteData();
  return _Picture(image.width, image.height, rgba!);
}))!;

/// How many of 72 points around the ring, [dp] inside the edge, have
/// [color].
int _ringPoints(_Picture picture, double ratio, double dp, Color color) {
  final radius = picture.width / 2 - dp * ratio;
  final centre = picture.width / 2;
  var count = 0;
  for (var i = 0; i < 72; i++) {
    final angle = i * math.pi / 36;
    final x = (centre + radius * math.cos(angle)).floor();
    final y = (centre + radius * math.sin(angle)).floor();
    if (picture.at(x, y) == color) count++;
  }
  return count;
}

void main() {
  group('HouseDotLook', () {
    test('should be a white round ringed in grey with ○ when to do', () {
      final look = HouseDotLook.of(HouseDotStatus.toDo, _colors);

      expect(look.fill, _colors.toDo);
      expect(look.border, _colors.muted);
      expect(look.dashed, isFalse);
      expect(look.glyph, StatusGlyphs.toDo);
      expect(look.glyphColor, _colors.onToDo);
    });

    test('should be a green round with ✓ when done', () {
      final look = HouseDotLook.of(HouseDotStatus.done, _colors);

      expect(look.fill, _colors.done);
      expect(look.border, _colors.doneBorder);
      expect(look.dashed, isFalse);
      expect(look.glyph, StatusGlyphs.done);
      expect(look.glyphColor, _colors.onDone);
    });

    test('should be a yellow round with ✗ when nobody was home', () {
      final look = HouseDotLook.of(HouseDotStatus.nobodyHome, _colors);

      expect(look.fill, _colors.nobodyHome);
      expect(look.border, _colors.nobodyHomeBorder);
      expect(look.dashed, isFalse);
      expect(look.glyph, StatusGlyphs.nobodyHome);
      expect(look.glyphColor, _colors.onNobodyHome);
    });

    test('should be a blue round ringed in dark blue with ↻ to come back', () {
      final look = HouseDotLook.of(HouseDotStatus.comeBack, _colors);

      expect(look.fill, _colors.comeBack);
      expect(look.border, _colors.onComeBack);
      expect(look.dashed, isFalse);
      expect(look.glyph, StatusGlyphs.comeBack);
      expect(look.glyphColor, _colors.onComeBack);
    });

    test('should be a beige round with a dashed ring and ◐ when partial', () {
      final look = HouseDotLook.of(HouseDotStatus.partial, _colors);

      expect(look.fill, _colors.buildingPartial);
      expect(look.border, _colors.muted);
      expect(look.dashed, isTrue);
      expect(look.glyph, StatusGlyphs.buildingPartial);
      expect(look.glyphColor, _colors.onBuildingPartial);
    });

    test('should be equal when every field is', () {
      final done = HouseDotLook.of(HouseDotStatus.done, _colors);

      expect(done, HouseDotLook.of(HouseDotStatus.done, _colors));
      expect(
        done.hashCode,
        HouseDotLook.of(HouseDotStatus.done, _colors).hashCode,
      );
      expect(done, isNot(HouseDotLook.of(HouseDotStatus.toDo, _colors)));
    });
  });

  group('HouseDotPainter', () {
    test('should repaint only when the look changes', () {
      final done = HouseDotPainter(
        HouseDotLook.of(HouseDotStatus.done, _colors),
      );

      expect(
        done.shouldRepaint(
          HouseDotPainter(HouseDotLook.of(HouseDotStatus.done, _colors)),
        ),
        isFalse,
      );
      expect(
        done.shouldRepaint(
          HouseDotPainter(HouseDotLook.of(HouseDotStatus.toDo, _colors)),
        ),
        isTrue,
      );
    });
  });

  group('houseDotPng', () {
    testWidgets('should draw 30 dp at the pixel ratio', (tester) async {
      final atTwo = await _draw(tester, HouseDotStatus.done, ratio: 2);
      final atThree = await _draw(tester, HouseDotStatus.done, ratio: 2.625);

      expect((atTwo.width, atTwo.height), (60, 60));
      // 78.75 pixels, rounded up so the dot is never cut.
      expect((atThree.width, atThree.height), (79, 79));
    });

    testWidgets('should leave the corners outside the round clear', (
      tester,
    ) async {
      final picture = await _draw(tester, HouseDotStatus.done);

      expect(picture.at(0, 0).a, 0);
      expect(picture.at(119, 119).a, 0);
    });

    testWidgets('should fill the round with the status colour', (tester) async {
      final done = await _draw(tester, HouseDotStatus.done);
      final nobody = await _draw(tester, HouseDotStatus.nobodyHome);

      // 4 dp under the top, in the middle: past the ring, above the glyph.
      expect(done.at(60, 16), _colors.done);
      expect(nobody.at(60, 16), _colors.nobodyHome);
    });

    testWidgets('should draw the glyph in the middle', (tester) async {
      final picture = await _draw(tester, HouseDotStatus.toDo);

      // The ○ of « à faire » is a ring 8.5/24 of the glyph from its
      // centre: 5.7 dp right of the dot's centre.
      expect(picture.at(60 + 23, 60), _colors.onToDo);
      expect(picture.at(60, 60), _colors.toDo);
    });

    testWidgets('should ring a house with a solid line', (tester) async {
      final picture = await _draw(tester, HouseDotStatus.toDo);

      expect(_ringPoints(picture, 4, 0.75, _colors.muted), 72);
    });

    testWidgets('should ring a building partly done with dashes', (
      tester,
    ) async {
      final picture = await _draw(tester, HouseDotStatus.partial);
      final onRing = _ringPoints(picture, 4, 0.75, _colors.muted);

      expect(onRing, greaterThan(20));
      expect(onRing, lessThan(60));
    });
  });
}
