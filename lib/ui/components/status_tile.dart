import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/building_icon.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// A house or building tile of the street screen: the number on the left,
/// the status glyph on the right, tinted per status (PLAN §5.6).
///
/// A building also shows a building icon before its number and a « › » at
/// the right edge, whatever its status: a tap opens it instead of changing
/// a status.
///
/// Status is never shown by colour alone: the glyph is always drawn, and
/// screen readers hear one French sentence (« Numéro 3bis, fait ») instead of
/// the number and count texts.
final class StatusTile extends StatelessWidget {
  const StatusTile({
    super.key,
    required this.number,
    required this.status,
    this.isBuilding = false,
    this.onTap,
    this.onLongPress,
  }) : assert(
         isBuilding || status is! BuildingPartialTile,
         'Only a building can be partly done.',
       );

  /// The house number as displayed, e.g. `3bis`.
  final String number;
  final TileStatus status;

  /// A building: icon, « › », and « immeuble … ouvrir » for screen readers.
  final bool isBuilding;

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
        // The tile has a fixed height (below), so the row fills it and
        // stays centred in it.
        child: Padding(
          padding: isBuilding
              ? const EdgeInsetsDirectional.only(
                  start: AppSizes.buildingTileStartPadding,
                  end: AppSizes.buildingTileEndPadding,
                )
              : const EdgeInsets.symmetric(horizontal: AppSizes.tilePadding),
          child: Row(
            spacing: AppSizes.glyphGap,
            children: [
              if (isBuilding)
                BuildingIcon(size: AppSizes.smallIcon, color: look.foreground),
              Expanded(
                child: _NumberAndStatus(number: number, look: look),
              ),
              if (isBuilding)
                OpenChevron(height: AppSizes.smallIcon, color: look.foreground),
            ],
          ),
        ),
      ),
    );
    if (look.dashedBorder) {
      tile = CustomPaint(
        foregroundPainter: DashedOutlinePainter(look.border),
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

  String _semanticsLabel(AppLocalizations l10n) => switch (status) {
    ToDoTile() => _withStatus(l10n, l10n.tileStatusToDo),
    DoneTile() => _withStatus(l10n, l10n.tileStatusDone),
    NobodyHomeTile() => _withStatus(l10n, l10n.tileStatusNobodyHome),
    ComeBackTile() => _withStatus(l10n, l10n.tileStatusComeBack),
    BuildingPartialTile(:final done, :final total) =>
      l10n.buildingTileSemantics(number, done, total),
  };

  /// « Numéro 3bis, fait », or « Numéro 8, immeuble, fait, ouvrir ».
  String _withStatus(AppLocalizations l10n, String spokenStatus) => isBuilding
      ? l10n.buildingStatusTileSemantics(number, spokenStatus)
      : l10n.houseTileSemantics(number, spokenStatus);
}

/// The number, then the status glyph and a building's count (`◐ 7/12`).
///
/// The number gives way first: it is cut with an ellipsis when the row is
/// short. But it always keeps [AppSizes.tileNumberMinWidth]; on a narrow
/// phone with large text, the glyph and count shrink to leave it that.
final class _NumberAndStatus extends StatelessWidget {
  const _NumberAndStatus({required this.number, required this.look});

  final String number;
  final StatusLook look;

  @override
  Widget build(BuildContext context) {
    final status = Row(
      // As narrow as its content, not as wide as the space it is given.
      mainAxisSize: MainAxisSize.min,
      spacing: AppSizes.glyphGap,
      children: [
        StatusGlyph(look.glyph, size: look.glyphSize, color: look.foreground),
        if (look.count case final count?)
          Text(
            count,
            style: AppTextStyles.tileCount.copyWith(color: look.foreground),
          ),
      ],
    );
    // `LayoutBuilder` hands over the width this widget is given, which the
    // limit of the status depends on.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: AppSizes.glyphGap,
        children: [
          Expanded(
            child: Text(
              number,
              style: AppTextStyles.tileNumber.copyWith(color: look.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  constraints.maxWidth -
                  AppSizes.tileNumberMinWidth -
                  AppSizes.glyphGap,
            ),
            // `scaleDown` draws the status at its own size when it fits,
            // and smaller (never larger) when it does not.
            child: FittedBox(fit: BoxFit.scaleDown, child: status),
          ),
        ],
      ),
    );
  }
}
