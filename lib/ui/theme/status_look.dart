import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// What a tile shows, independent of how the domain stores it.
///
/// A `sealed` class lists all its subclasses in this file, so a `switch` over
/// a `TileStatus` must handle every one of them: adding a status breaks the
/// build wherever it still needs a look or a label. T1.7 maps the domain's
/// `VisitStatus` (and buildings) onto these.
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

/// « Repasser »: asked to come back later.
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

/// The status glyphs of PLAN §5, the only list of them.
///
/// They are drawn as vector shapes by `StatusGlyph`
/// (`ui/components/status_glyph.dart`), not typed as characters: the bundled
/// fonts lack ○ ↻ ◐, and the phone's fallback font draws them smaller than
/// ✓ ✗. The comment on each value is the character it stands for.
enum StatusGlyphs {
  /// ○ à faire.
  toDo,

  /// ✓ fait.
  done,

  /// ✗ personne.
  nobodyHome,

  /// ↻ repasser.
  comeBack,

  /// ◐ immeuble en partie fait.
  buildingPartial,
}

/// Colours, glyph and outline of a tile for one status: the single source of
/// the status treatments of `docs/mockups/README.md`.
@immutable
final class StatusLook {
  const StatusLook({
    required this.glyph,
    required this.glyphSize,
    this.count,
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
          glyphSize: AppSizes.tileGlyph,
          background: colors.toDo,
          foreground: colors.onToDo,
          border: colors.toDoBorder,
          dashedBorder: false,
        ),
        DoneTile() => StatusLook(
          glyph: StatusGlyphs.done,
          glyphSize: AppSizes.tileGlyph,
          background: colors.done,
          foreground: colors.onDone,
          border: colors.doneBorder,
          dashedBorder: false,
        ),
        NobodyHomeTile() => StatusLook(
          glyph: StatusGlyphs.nobodyHome,
          glyphSize: AppSizes.tileGlyph,
          background: colors.nobodyHome,
          foreground: colors.onNobodyHome,
          border: colors.nobodyHomeBorder,
          dashedBorder: false,
        ),
        ComeBackTile() => StatusLook(
          glyph: StatusGlyphs.comeBack,
          glyphSize: AppSizes.tileGlyph,
          background: colors.comeBack,
          foreground: colors.onComeBack,
          border: colors.comeBackBorder,
          dashedBorder: false,
        ),
        BuildingPartialTile(:final done, :final total) => StatusLook(
          glyph: StatusGlyphs.buildingPartial,
          glyphSize: AppSizes.tileBuildingGlyph,
          count: '$done/$total',
          background: colors.buildingPartial,
          foreground: colors.onBuildingPartial,
          border: colors.buildingPartialBorder,
          dashedBorder: true,
        ),
      };

  /// The glyph at the tile's right edge.
  final StatusGlyphs glyph;

  /// Side of the glyph's square box, in dp.
  final double glyphSize;

  /// Text written after the glyph: `7/12` on a building, nothing on a house.
  final String? count;
  final Color background;
  final Color foreground;
  final Color border;

  /// Buildings have a dashed outline, houses a solid one.
  final bool dashedBorder;
}
