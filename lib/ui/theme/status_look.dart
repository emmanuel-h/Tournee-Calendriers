import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// What a tile shows, independent of how the domain stores it.
///
/// A `sealed` class lists all its subclasses in this file, so a `switch` over
/// a `TileStatus` must handle every one of them: adding a status breaks the
/// build wherever it still needs a look or a label. T1.7 maps the domain's
/// `VisitStatus` (plus « repasser » and buildings) onto these.
sealed class TileStatus {
  const TileStatus();
}

/// Not visited yet.
final class ToDoTile extends TileStatus {
  const ToDoTile();
}

/// Calendar handed over.
final class DoneTile extends TileStatus {
  const DoneTile();
}

/// Nobody answered.
final class NobodyHomeTile extends TileStatus {
  const NobodyHomeTile();
}

/// Not visited yet, with a « repasser » hint.
final class ComeBackTile extends TileStatus {
  const ComeBackTile();
}

/// A building where [done] of its [total] dwellings are done.
final class BuildingPartialTile extends TileStatus {
  const BuildingPartialTile({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is BuildingPartialTile &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(done, total);
}

/// The status glyphs of PLAN §5, the only place they are written.
abstract final class StatusGlyphs {
  static const toDo = '○';
  static const done = '✓';
  static const nobodyHome = '✗';
  static const comeBack = '↻';
  static const buildingPartial = '◐';
}

/// Colours, glyph and outline of a tile for one status: the single source of
/// the status treatments of `docs/mockups/README.md`.
@immutable
final class StatusLook {
  const StatusLook({
    required this.glyph,
    required this.glyphStyle,
    required this.background,
    required this.foreground,
    required this.border,
    required this.dashedBorder,
  });

  /// Picks the look of [status] from [colors].
  factory StatusLook.of(TileStatus status, AppColors colors) =>
      switch (status) {
        ToDoTile() => StatusLook(
          glyph: StatusGlyphs.toDo,
          glyphStyle: AppTextStyles.tileGlyph,
          background: colors.toDo,
          foreground: colors.onToDo,
          border: colors.toDoBorder,
          dashedBorder: false,
        ),
        DoneTile() => StatusLook(
          glyph: StatusGlyphs.done,
          glyphStyle: AppTextStyles.tileGlyph,
          background: colors.done,
          foreground: colors.onDone,
          border: colors.doneBorder,
          dashedBorder: false,
        ),
        NobodyHomeTile() => StatusLook(
          glyph: StatusGlyphs.nobodyHome,
          glyphStyle: AppTextStyles.tileGlyph,
          background: colors.nobodyHome,
          foreground: colors.onNobodyHome,
          border: colors.nobodyHomeBorder,
          dashedBorder: false,
        ),
        ComeBackTile() => StatusLook(
          glyph: StatusGlyphs.comeBack,
          glyphStyle: AppTextStyles.tileGlyph,
          background: colors.comeBack,
          foreground: colors.onComeBack,
          border: colors.comeBackBorder,
          dashedBorder: false,
        ),
        BuildingPartialTile(:final done, :final total) => StatusLook(
          glyph: '${StatusGlyphs.buildingPartial} $done/$total',
          glyphStyle: AppTextStyles.tileBuildingGlyph,
          background: colors.buildingPartial,
          foreground: colors.onBuildingPartial,
          border: colors.buildingPartialBorder,
          dashedBorder: true,
        ),
      };

  /// What the tile shows at its right edge: a glyph, or `◐ 7/12`.
  final String glyph;
  final TextStyle glyphStyle;
  final Color background;
  final Color foreground;
  final Color border;

  /// Buildings have a dashed outline, houses a solid one.
  final bool dashedBorder;
}
