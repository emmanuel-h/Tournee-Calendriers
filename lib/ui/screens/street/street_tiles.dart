import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/components/status_tile.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// The tiles of both sides, scrolling together, with the tap hint floating
/// at the bottom while no snackbar shows.
///
/// Built lazily, one row (an odd tile and an even tile) at a time:
/// `ListView.builder` only builds the rows on screen, so a street of 400
/// numbers scrolls as smoothly as one of 10. Each side keeps its own order;
/// the two tiles of a row are just the n-th of each side, as in the mockup.
final class StreetTiles extends StatelessWidget {
  const StreetTiles({
    super.key,
    required this.state,
    required this.showHint,
    required this.onTap,
    required this.onHold,
  });

  final StreetShown state;

  /// The hint « Appui : ○ → ✓ → ✗ → ○ · Appui long : détails » shows; it
  /// gives way to the snackbar.
  final bool showHint;

  /// A house tile was tapped.
  final ValueChanged<HouseNumber> onTap;

  /// A house tile was held (long-pressed).
  final ValueChanged<HouseNumber> onHold;

  @override
  Widget build(BuildContext context) {
    final columns = switch (state.columns) {
      StreetColumns.both => [state.odd, state.even],
      StreetColumns.oddOnly => [state.odd],
      StreetColumns.evenOnly => [state.even],
    };
    final rows = columns
        .map((side) => side.length)
        .fold(0, (longest, length) => length > longest ? length : longest);
    return Stack(
      children: [
        ListView.builder(
          key: const Key('street.tiles'),
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            0,
            AppSizes.gutter,
            AppSizes.streetListBottom,
          ),
          // Every row has the same height: the list knows where each one is
          // without building it, so a long fling stays smooth.
          itemExtent: AppSizes.tileHeight + AppSizes.tileGap,
          itemCount: rows,
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.tileGap),
            child: Row(
              spacing: AppSizes.columnGap,
              children: [
                for (final side in columns)
                  Expanded(
                    child: row < side.length
                        ? _tile(side[row])
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
        if (showHint)
          const Positioned(
            left: AppSizes.gutter,
            right: AppSizes.gutter,
            bottom: AppSizes.floatingBottom,
            child: _TapHint(),
          ),
      ],
    );
  }

  Widget _tile(HouseTile tile) {
    final number = tile.number;
    return StatusTile(
      key: ValueKey('street.tile.${number.label}'),
      number: number.label,
      status: switch (tile.mark) {
        ToDoMark() => const ToDoTile(),
        DoneMark() => const DoneTile(),
        NobodyHomeMark() => const NobodyHomeTile(),
        ComeBackMark() => const ComeBackTile(),
        PartialBuildingMark(:final done, :final total) => BuildingPartialTile(
          done: done,
          total: total,
        ),
      },
      hasNote: tile.hasNote,
      // A building opens its grid on tap (#13): not cycled here, and its
      // own sheet is not wired yet.
      onTap: tile.isBuilding ? null : () => onTap(number),
      onLongPress: tile.isBuilding ? null : () => onHold(number),
    );
  }
}

/// « Appui : ○ → ✓ → ✗ → ○ · Appui long : détails », in a white pill.
final class _TapHint extends StatelessWidget {
  const _TapHint();

  static const _glyphSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    WidgetSpan glyph(StatusGlyphs which) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: StatusGlyph(which, size: _glyphSize, color: colors.muted),
    );
    const arrow = TextSpan(text: ' → ');
    return Semantics(
      label: l10n.tapHintSemantics,
      excludeSemantics: true,
      child: Container(
        key: const Key('street.hint'),
        height: AppSizes.hintHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(AppSizes.hintHeight / 2),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l10n.tapHintTap} '),
              glyph(StatusGlyphs.toDo),
              arrow,
              glyph(StatusGlyphs.done),
              arrow,
              glyph(StatusGlyphs.nobodyHome),
              arrow,
              glyph(StatusGlyphs.toDo),
              TextSpan(text: ' · ${l10n.tapHintHold}'),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.small.copyWith(color: colors.muted),
        ),
      ),
    );
  }
}
