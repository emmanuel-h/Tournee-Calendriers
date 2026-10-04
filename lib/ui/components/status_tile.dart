import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// A house or building tile of the street screen: the number on the left,
/// the status glyph on the right, tinted per status (PLAN §5.6).
///
/// Status is never shown by colour alone: the glyph is always drawn, and
/// screen readers hear one French sentence (« Numéro 3bis, fait ») instead of
/// the number and count texts.
final class StatusTile extends StatelessWidget {
  const StatusTile({
    super.key,
    required this.number,
    required this.status,
    this.hasNote = false,
    this.onTap,
    this.onLongPress,
  });

  /// The house number as displayed, e.g. `3bis`.
  final String number;
  final TileStatus status;

  /// The house has a note: a small dot in the top corner (PLAN §5.6), and
  /// « avec une note » for screen readers.
  final bool hasNote;

  /// Tap cycles the status, or opens a building (PLAN §5).
  final VoidCallback? onTap;

  /// Hold opens the details (PLAN §5).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final look = StatusLook.of(status, AppColors.of(context));
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.tileRadius),
      // A dashed outline is painted separately below; Flutter borders are
      // always solid.
      side: look.dashedBorder
          ? BorderSide.none
          : BorderSide(color: look.border, width: AppSizes.borderWidth),
    );

    Widget tile = Material(
      color: look.background,
      shape: shape,
      // Clips the ink ripple to the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        // `expand`: the number and glyph row fills the tile (and stays
        // centred in it), the dot is placed over it.
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.tilePadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      number,
                      style: AppTextStyles.tileNumber.copyWith(
                        color: look.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusGlyph(
                    look.glyph,
                    size: look.glyphSize,
                    color: look.foreground,
                  ),
                  if (look.count case final count?) ...[
                    const SizedBox(width: AppSizes.glyphGap),
                    Text(
                      count,
                      style: AppTextStyles.tileCount.copyWith(
                        color: look.foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasNote)
              Positioned(
                key: const Key('tile.note'),
                top: AppSizes.noteDot,
                right: AppSizes.noteDot,
                child: Container(
                  width: AppSizes.noteDot,
                  height: AppSizes.noteDot,
                  decoration: BoxDecoration(
                    color: look.foreground,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (look.dashedBorder) {
      tile = CustomPaint(
        foregroundPainter: _DashedOutlinePainter(look.border),
        child: tile,
      );
    }

    // `excludeSemantics` hides the two texts from screen readers, which hear
    // the label instead; `button` makes TalkBack announce it as tappable.
    return Semantics(
      label: _semanticsLabel(AppLocalizations.of(context)),
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(height: AppSizes.tileHeight, child: tile),
    );
  }

  String _semanticsLabel(AppLocalizations l10n) {
    final label = _statusLabel(l10n);
    return hasNote ? l10n.tileWithNoteSemantics(label) : label;
  }

  String _statusLabel(AppLocalizations l10n) => switch (status) {
    ToDoTile() => l10n.houseTileSemantics(number, l10n.tileStatusToDo),
    DoneTile() => l10n.houseTileSemantics(number, l10n.tileStatusDone),
    NobodyHomeTile() => l10n.houseTileSemantics(
      number,
      l10n.tileStatusNobodyHome,
    ),
    ComeBackTile() => l10n.houseTileSemantics(number, l10n.tileStatusComeBack),
    BuildingPartialTile(:final done, :final total) =>
      l10n.buildingTileSemantics(number, done, total),
  };
}

/// Draws the dashed rounded outline of building tiles.
final class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter(this.color);

  final Color color;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AppSizes.borderWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(inset),
          const Radius.circular(AppSizes.tileRadius - inset),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.borderWidth;
    // Walks along the outline and keeps one dash every `_dash + _gap` pixels.
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        canvas.drawPath(metric.extractPath(start, start + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
