import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// How a house dot looks for one status (HomeZoom mockup): a round of
/// [fill] ringed with [border] (dashed for a building partly done), the
/// status [glyph] in [glyphColor] in the middle. The glyph, not the colour
/// alone, tells the status (PLAN §5).
@immutable
final class HouseDotLook {
  const HouseDotLook({
    required this.fill,
    required this.border,
    required this.dashed,
    required this.glyph,
    required this.glyphColor,
  });

  /// The look of a dot with [status], from the tile colours of [colors].
  /// The ring of « à faire » and of a building is darker than a tile's
  /// border ([AppColors.muted]): a white dot on a pale map needs it to be
  /// seen.
  factory HouseDotLook.of(HouseDotStatus status, AppColors colors) =>
      switch (status) {
        HouseDotStatus.toDo => HouseDotLook(
          fill: colors.toDo,
          border: colors.muted,
          dashed: false,
          glyph: StatusGlyphs.toDo,
          glyphColor: colors.onToDo,
        ),
        HouseDotStatus.done => HouseDotLook(
          fill: colors.done,
          border: colors.doneBorder,
          dashed: false,
          glyph: StatusGlyphs.done,
          glyphColor: colors.onDone,
        ),
        HouseDotStatus.nobodyHome => HouseDotLook(
          fill: colors.nobodyHome,
          border: colors.nobodyHomeBorder,
          dashed: false,
          glyph: StatusGlyphs.nobodyHome,
          glyphColor: colors.onNobodyHome,
        ),
        HouseDotStatus.comeBack => HouseDotLook(
          fill: colors.comeBack,
          border: colors.onComeBack,
          dashed: false,
          glyph: StatusGlyphs.comeBack,
          glyphColor: colors.onComeBack,
        ),
        HouseDotStatus.partial => HouseDotLook(
          fill: colors.buildingPartial,
          border: colors.muted,
          dashed: true,
          glyph: StatusGlyphs.buildingPartial,
          glyphColor: colors.onBuildingPartial,
        ),
      };

  final Color fill;
  final Color border;
  final bool dashed;
  final StatusGlyphs glyph;
  final Color glyphColor;

  @override
  bool operator ==(Object other) =>
      other is HouseDotLook &&
      other.fill == fill &&
      other.border == border &&
      other.dashed == dashed &&
      other.glyph == glyph &&
      other.glyphColor == glyphColor;

  @override
  int get hashCode => Object.hash(fill, border, dashed, glyph, glyphColor);
}

/// Paints a [HouseDotLook] in a square: the round fills it.
final class HouseDotPainter extends CustomPainter {
  const HouseDotPainter(this.look);

  final HouseDotLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = Offset(side / 2, side / 2);
    // The ring is drawn inside the square, so half its width is kept free.
    const inset = AppSizes.borderWidth / 2;
    canvas.drawCircle(centre, side / 2 - inset, Paint()..color = look.fill);
    if (look.dashed) {
      DashedOutlinePainter(
        look.border,
        radius: side / 2,
      ).paint(canvas, Size.square(side));
    } else {
      canvas.drawCircle(
        centre,
        side / 2 - inset,
        Paint()
          ..color = look.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppSizes.borderWidth,
      );
    }
    const glyph = AppSizes.houseDotGlyph;
    canvas
      ..save()
      ..translate((side - glyph) / 2, (side - glyph) / 2);
    StatusGlyphPainter(
      look.glyph,
      look.glyphColor,
    ).paint(canvas, const Size.square(glyph));
    canvas.restore();
  }

  @override
  bool shouldRepaint(HouseDotPainter oldDelegate) => oldDelegate.look != look;
}

/// [look] drawn as a PNG picture of [AppSizes.houseDot] dp, at
/// [pixelRatio] pixels per dp: what the map shows for a house dot
/// (`addImage`).
///
/// A picture rather than a circle and a character, because the map's fonts
/// lack some glyphs (○ ↻ ◐) and draw the others at different sizes; the
/// glyphs are the same vector shapes as on the tiles. MapLibre reads a
/// picture as made for the screen's density, so drawing it at the phone's
/// pixel ratio gives a sharp dot of the right size.
Future<Uint8List> houseDotPng(HouseDotLook look, double pixelRatio) async {
  final pixels = (AppSizes.houseDot * pixelRatio).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  HouseDotPainter(look).paint(canvas, const Size.square(AppSizes.houseDot));
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}
