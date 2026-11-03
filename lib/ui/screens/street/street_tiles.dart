import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/status_tile.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

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
    required this.onOpenBuilding,
    this.selected,
  });

  final StreetShown state;

  /// The hint « Appuyez sur une maison pour changer son statut » shows; it
  /// gives way to the snackbar.
  final bool showHint;

  /// A house tile was tapped: its status picker opens.
  final ValueChanged<HouseNumber> onTap;

  /// A building tile was tapped: its grid opens.
  final ValueChanged<HouseNumber> onOpenBuilding;

  /// The house whose status picker shows, outlined; null when none does.
  final HouseNumber? selected;

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
          // A little room at the top for the calendars badge of a first
          // tile, drawn past its edge.
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            AppSizes.calendarBadgeOverhang,
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
      status: tileStatusOf(tile.mark),
      isBuilding: tile.isBuilding,
      tries: tile.tries,
      calendars: tile.calendars,
      selected: number == selected,
      // A building has no status of its own: its doors do, in its grid.
      onTap: tile.isBuilding
          ? () => onOpenBuilding(number)
          : () => onTap(number),
    );
  }
}

/// « Appuyez sur une maison pour changer son statut », in a white pill.
final class _TapHint extends StatelessWidget {
  const _TapHint();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: const Key('street.hint'),
      // At least the mockup's height; taller with a large phone font.
      constraints: const BoxConstraints(minHeight: AppSizes.hintHeight),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppSizes.hintHeight / 2),
      ),
      child: Text(
        AppLocalizations.of(context).streetHint,
        textAlign: TextAlign.center,
        style: AppTextStyles.small.copyWith(color: colors.muted),
      ),
    );
  }
}
