import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// The WCAG contrast ratio of two colours, from 1:1 to 21:1.
/// `computeLuminance` is the WCAG relative luminance.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Body text needs 4.5:1 (WCAG 1.4.3).
const _text = 4.5;

/// Borders, glyphs, bars and marks need 3:1 (WCAG 1.4.11).
const _graphic = 3.0;

/// A colour drawn on another, with the ratio it must reach.
typedef _Pair = (
  String name,
  Color Function(AppColors) front,
  Color Function(AppColors) back,
  double minimum,
);

/// Every pair the screens draw that carries meaning, checked in both
/// palettes. Status glyphs are drawn in the tile's text colour, so the
/// text pairs of the tiles cover them too.
final List<_Pair> _pairs = [
  ('ink on ground', (c) => c.ink, (c) => c.ground, _text),
  ('ink on surface', (c) => c.ink, (c) => c.surface, _text),
  ('muted on ground', (c) => c.muted, (c) => c.ground, _text),
  ('muted on surface', (c) => c.muted, (c) => c.surface, _text),
  ('onAccent on accent', (c) => c.onAccent, (c) => c.accent, _text),
  ('accent on surface', (c) => c.accent, (c) => c.surface, _text),
  ('accent on ground', (c) => c.accent, (c) => c.ground, _text),
  ('accent on alert', (c) => c.accent, (c) => c.alert, _text),
  ('ink on alert', (c) => c.ink, (c) => c.alert, _text),
  ('onDisabled on disabled', (c) => c.onDisabled, (c) => c.disabled, _text),
  ('ink on nobodyHomePale', (c) => c.ink, (c) => c.nobodyHomePale, _text),
  ('onToDo on toDo', (c) => c.onToDo, (c) => c.toDo, _text),
  ('onDone on done', (c) => c.onDone, (c) => c.done, _text),
  ('onRefused on refused', (c) => c.onRefused, (c) => c.refused, _text),
  (
    'refusedBorder on ground',
    (c) => c.refusedBorder,
    (c) => c.ground,
    _graphic,
  ),
  (
    'refusedBorder on surface',
    (c) => c.refusedBorder,
    (c) => c.surface,
    _graphic,
  ),
  (
    'onNobodyHome on nobodyHome',
    (c) => c.onNobodyHome,
    (c) => c.nobodyHome,
    _text,
  ),
  ('onComeBack on comeBack', (c) => c.onComeBack, (c) => c.comeBack, _text),
  ('onComeBack on surface', (c) => c.onComeBack, (c) => c.surface, _text),
  ('surface on onComeBack', (c) => c.surface, (c) => c.onComeBack, _text),
  (
    'onBuildingPartial on buildingPartial',
    (c) => c.onBuildingPartial,
    (c) => c.buildingPartial,
    _text,
  ),
  ('doneInk on surface', (c) => c.doneInk, (c) => c.surface, _text),
  ('doneInk on ground', (c) => c.doneInk, (c) => c.ground, _text),
  ('onSnackBar on snackBar', (c) => c.onSnackBar, (c) => c.snackBar, _text),
  (
    'snackBarAction on snackBar',
    (c) => c.snackBarAction,
    (c) => c.snackBar,
    _text,
  ),
  ('doneInk on divider', (c) => c.doneInk, (c) => c.divider, _graphic),
  ('accent on divider', (c) => c.accent, (c) => c.divider, _graphic),
  ('doneBorder on ground', (c) => c.doneBorder, (c) => c.ground, _graphic),
  (
    'editTileBorder on surface',
    (c) => c.editTileBorder,
    (c) => c.surface,
    _graphic,
  ),
];

/// Pairs the dark palette must reach but the approved light one does not:
/// the outlines of a to-do tile, a building and a « repasser » tile, and
/// of fields and secondary buttons. Their words tell what they are, so
/// WCAG does not require these outlines; the dark palette keeps them at
/// 3:1 because there a to-do tile and the ground are nearly the same
/// grey.
final List<_Pair> _darkOutlines = [
  ('toDoBorder on ground', (c) => c.toDoBorder, (c) => c.ground, _graphic),
  ('toDoBorder on surface', (c) => c.toDoBorder, (c) => c.surface, _graphic),
  ('line on ground', (c) => c.line, (c) => c.ground, _graphic),
  ('line on surface', (c) => c.line, (c) => c.surface, _graphic),
  (
    'buildingPartialBorder on ground',
    (c) => c.buildingPartialBorder,
    (c) => c.ground,
    _graphic,
  ),
  (
    'comeBackBorder on ground',
    (c) => c.comeBackBorder,
    (c) => c.ground,
    _graphic,
  ),
];

void _expectPairs(AppColors colors, List<_Pair> pairs) {
  for (final (name, front, back, minimum) in pairs) {
    expect(
      contrast(front(colors), back(colors)),
      greaterThanOrEqualTo(minimum),
      reason: name,
    );
  }
}

void main() {
  group('contrast', () {
    test('should be 21 when black is on white', () {
      expect(
        contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('should be 1 when a colour is on itself', () {
      expect(
        contrast(const Color(0xFF1E6B47), const Color(0xFF1E6B47)),
        closeTo(1, 0.0001),
      );
    });

    test('should not depend on which colour is in front', () {
      const a = Color(0xFF1E6B47);
      const b = Color(0xFFF3F1EC);
      expect(contrast(a, b), closeTo(5.73, 0.01));
      expect(contrast(b, a), closeTo(5.73, 0.01));
    });
  });

  test('should reach the WCAG ratios when the light palette is used', () {
    _expectPairs(AppColors.light, _pairs);
  });

  test('should reach the WCAG ratios when the dark palette is used', () {
    _expectPairs(AppColors.dark, _pairs);
  });

  test('should outline tiles and fields at 3:1 when the palette is dark', () {
    _expectPairs(AppColors.dark, _darkOutlines);
  });

  test('should draw a refused tile in the mockups\' dark grey with white '
      'text in both palettes', () {
    for (final colors in [AppColors.light, AppColors.dark]) {
      expect(colors.refused, const Color(0xFF5A6068));
      expect(colors.onRefused, const Color(0xFFFFFFFF));
    }
    expect(AppColors.light.refusedBorder, const Color(0xFF5A6068));
  });

  test('should draw the map lines in the light colours in both palettes', () {
    // The base map is light whatever the theme.
    const light = AppColors.light;
    const dark = AppColors.dark;
    expect(dark.mapStreetDone, light.mapStreetDone);
    expect(dark.mapStreetPartial, light.mapStreetPartial);
    expect(dark.mapStreetToDo, light.mapStreetToDo);
    expect(dark.mapSelectedCasing, light.mapSelectedCasing);
    expect(dark.mapSelectedCore, light.mapSelectedCore);
  });
}
