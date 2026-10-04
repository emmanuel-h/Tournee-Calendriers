import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

void main() {
  const colors = AppColors.light;

  test(
    'should use the white tile and solid outline when the house is to do',
    () {
      final look = StatusLook.of(const ToDoTile(), colors);

      expect(look.glyph, '○');
      expect(look.glyphStyle, AppTextStyles.tileGlyph);
      expect(look.background, const Color(0xFFFFFFFF));
      expect(look.foreground, const Color(0xFF1B1F24));
      expect(look.border, const Color(0xFFCFC9BD));
      expect(look.dashedBorder, isFalse);
    },
  );

  test('should use the green tile with white text when the house is done', () {
    final look = StatusLook.of(const DoneTile(), colors);

    expect(look.glyph, '✓');
    expect(look.glyphStyle, AppTextStyles.tileGlyph);
    expect(look.background, const Color(0xFF1E6B47));
    expect(look.foreground, const Color(0xFFFFFFFF));
    expect(look.border, const Color(0xFF1E6B47));
    expect(look.dashedBorder, isFalse);
  });

  test('should use the yellow tile with ink text when nobody was home', () {
    final look = StatusLook.of(const NobodyHomeTile(), colors);

    expect(look.glyph, '✗');
    expect(look.glyphStyle, AppTextStyles.tileGlyph);
    expect(look.background, const Color(0xFFF2B33D));
    expect(look.foreground, const Color(0xFF1B1F24));
    expect(look.border, const Color(0xFFD99A22));
    expect(look.dashedBorder, isFalse);
  });

  test('should use the blue tile when the house is to come back to', () {
    final look = StatusLook.of(const ComeBackTile(), colors);

    expect(look.glyph, '↻');
    expect(look.glyphStyle, AppTextStyles.tileGlyph);
    expect(look.background, const Color(0xFFD6E6F5));
    expect(look.foreground, const Color(0xFF1D4E7A));
    expect(look.border, const Color(0xFFA9C8E6));
    expect(look.dashedBorder, isFalse);
  });

  test('should show the count with a dashed outline when a building is partly done', () {
    final look = StatusLook.of(
      const BuildingPartialTile(done: 7, total: 12),
      colors,
    );

    expect(look.glyph, '◐ 7/12');
    expect(look.glyphStyle, AppTextStyles.tileBuildingGlyph);
    expect(look.background, const Color(0xFFEFE9DD));
    expect(look.foreground, const Color(0xFF1B1F24));
    expect(look.border, const Color(0xFFCFC9BD));
    expect(look.dashedBorder, isTrue);
  });

  test('should take its colours from the palette it is given', () {
    final look = StatusLook.of(const DoneTile(), AppColors.dark);

    expect(look.background, AppColors.dark.done);
    expect(look.foreground, AppColors.dark.onDone);
    expect(look.border, AppColors.dark.doneBorder);
  });

  test('should compare building statuses by their counts', () {
    const a = BuildingPartialTile(done: 7, total: 12);

    expect(a, const BuildingPartialTile(done: 7, total: 12));
    expect(a.hashCode, const BuildingPartialTile(done: 7, total: 12).hashCode);
    expect(a, isNot(const BuildingPartialTile(done: 6, total: 12)));
    expect(a, isNot(const BuildingPartialTile(done: 7, total: 11)));
  });
}
