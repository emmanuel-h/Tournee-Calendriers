import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/ring_pulse.dart';
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
///
/// A house [ringed] (opened from « À repasser », PLAN §5.17) is scrolled to
/// the middle of the screen once, and ringed for a moment.
final class StreetTiles extends StatefulWidget {
  const StreetTiles({
    super.key,
    required this.state,
    required this.showHint,
    required this.onTap,
    required this.onOpenBuilding,
    this.selected,
    this.hint,
    this.ringed,
  });

  final StreetShown state;

  /// The hint « Appuyez sur une maison pour changer son statut » (or
  /// [hint]) shows; it gives way to the snackbar.
  final bool showHint;

  /// What the hint pill says instead of « Appuyez sur une maison… »; null
  /// for that.
  final String? hint;

  /// The house to scroll to and ring; null for none.
  final HouseNumber? ringed;

  /// A house tile was tapped: its status picker opens.
  final ValueChanged<HouseNumber> onTap;

  /// A building tile was tapped: its grid opens.
  final ValueChanged<HouseNumber> onOpenBuilding;

  /// The house whose status picker shows, outlined; null when none does.
  final HouseNumber? selected;

  @override
  State<StreetTiles> createState() => _StreetTilesState();
}

/// A `State` for the list's `ScrollController`, which brings the house
/// ringed into view.
final class _StreetTilesState extends State<StreetTiles> {
  final _scroll = ScrollController();

  /// The house already scrolled to, so the list moves once only.
  HouseNumber? _scrolledTo;

  /// Every row has the same height (see `itemExtent`).
  static const _rowExtent = AppSizes.tileHeight + AppSizes.tileGap;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<List<HouseTile>> get _columns => switch (widget.state.columns) {
    StreetColumns.both => [widget.state.odd, widget.state.even],
    StreetColumns.oddOnly => [widget.state.odd],
    StreetColumns.evenOnly => [widget.state.even],
  };

  /// Scrolls the row of the house ringed to the middle of the list, once
  /// the list is laid out.
  void _scrollToRinged(List<List<HouseTile>> columns) {
    final ringed = widget.ringed;
    if (ringed == null || ringed == _scrolledTo) return;
    final row = columns
        .map((side) => side.indexWhere((tile) => tile.number == ringed))
        .firstWhere((index) => index >= 0, orElse: () => -1);
    if (row < 0) return;
    _scrolledTo = ringed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final middle =
          AppSizes.calendarBadgeOverhang +
          row * _rowExtent +
          _rowExtent / 2 -
          position.viewportDimension / 2;
      _scroll.jumpTo(
        middle.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    _scrollToRinged(columns);
    final rows = columns
        .map((side) => side.length)
        .fold(0, (longest, length) => length > longest ? length : longest);
    return Stack(
      children: [
        ListView.builder(
          key: const Key('street.tiles'),
          controller: _scroll,
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
          itemExtent: _rowExtent,
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
        if (widget.showHint)
          Positioned(
            left: AppSizes.gutter,
            right: AppSizes.gutter,
            bottom: AppSizes.floatingBottom,
            child: _TapHint(widget.hint),
          ),
      ],
    );
  }

  Widget _tile(HouseTile tile) {
    final number = tile.number;
    final statusTile = StatusTile(
      key: ValueKey('street.tile.${number.label}'),
      number: number.label,
      status: tileStatusOf(tile.mark),
      isBuilding: tile.isBuilding,
      tries: tile.tries,
      calendars: tile.calendars,
      selected: number == widget.selected,
      // A building has no status of its own: its doors do, in its grid.
      onTap: tile.isBuilding
          ? () => widget.onOpenBuilding(number)
          : () => widget.onTap(number),
    );
    return number == widget.ringed
        ? RingPulse(key: const Key('street.ring'), child: statusTile)
        : statusTile;
  }
}

/// « Appuyez sur une maison pour changer son statut », or [text], in a
/// white pill.
final class _TapHint extends StatelessWidget {
  const _TapHint(this.text);

  final String? text;

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
        text ?? AppLocalizations.of(context).streetHint,
        textAlign: TextAlign.center,
        style: AppTextStyles.small.copyWith(color: colors.muted),
      ),
    );
  }
}
