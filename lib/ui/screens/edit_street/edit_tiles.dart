import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_state.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Côté impair | Côté pair », then the dashed numbers of each side with
/// « + numéros » closing each column, and the hint under them (Edit
/// mockup). One column when the street has numbers on one side only.
///
/// Built lazily, one row at a time, like the street screen: row n holds
/// the n-th number of each side, or that side's « + numéros » once its
/// numbers are listed.
final class EditColumns extends StatelessWidget {
  const EditColumns({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
  });

  final EditStreetShown state;

  /// A number was tapped: its sheet opens.
  final ValueChanged<HouseNumber> onEdit;

  /// The ✕ of a number was tapped.
  final ValueChanged<HouseNumber> onRemove;

  /// « + numéros » was tapped.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final sides = switch (state.columns) {
      StreetColumns.both => [
        ('odd', l10n.oddSide, state.odd),
        ('even', l10n.evenSide, state.even),
      ],
      StreetColumns.oddOnly => [('odd', l10n.oddSide, state.odd)],
      StreetColumns.evenOnly => [('even', l10n.evenSide, state.even)],
    };
    final longest = sides
        .map((side) => side.$3.length)
        .fold(0, (longest, length) => length > longest ? length : longest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            14,
            AppSizes.gutter,
            6,
          ),
          child: Row(
            spacing: AppSizes.columnGap,
            children: [
              for (final (_, title, _) in sides)
                Expanded(child: SectionHeader(title, padding: EdgeInsets.zero)),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: const Key('edit.tiles'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.gutter,
                ),
                // Fixed-height rows: the list knows where each one is
                // without building it.
                sliver: SliverFixedExtentList(
                  itemExtent: AppSizes.editTileHeight + AppSizes.tileGap,
                  delegate: SliverChildBuilderDelegate(
                    // One row more than the longest side, for the last
                    // « + numéros ».
                    childCount: longest + 1,
                    (context, row) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.tileGap),
                      child: Row(
                        spacing: AppSizes.columnGap,
                        children: [
                          for (final (side, _, tiles) in sides)
                            Expanded(child: _cell(side, tiles, row)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.gutter,
                  4,
                  AppSizes.gutter,
                  AppSizes.gutter,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.editHint,
                    style: AppTextStyles.small.copyWith(
                      color: colors.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The n-th cell of the column of [side] (`odd`, `even`).
  Widget _cell(String side, List<EditTile> tiles, int row) {
    if (row < tiles.length) {
      final tile = tiles[row];
      return EditNumberTile(
        key: ValueKey('edit.tile.${tile.number.label}'),
        tile: tile,
        onEdit: () => onEdit(tile.number),
        onRemove: () => onRemove(tile.number),
      );
    }
    if (row == tiles.length) {
      return _AddNumbersButton(
        key: ValueKey('edit.addNumbers.$side'),
        onPressed: onAdd,
      );
    }
    return const SizedBox.shrink();
  }
}

/// A number in edit mode: white, a dashed grey outline, the number (or
/// « 8 · immeuble ») to tap, and a red ✕ on the right.
final class EditNumberTile extends StatelessWidget {
  const EditNumberTile({
    super.key,
    required this.tile,
    required this.onEdit,
    required this.onRemove,
  });

  final EditTile tile;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final label = tile.number.label;
    return CustomPaint(
      foregroundPainter: DashedOutlinePainter(colors.editTileBorder),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: tile.isBuilding
                    ? l10n.editBuildingTileSemantics(label)
                    : l10n.editTileSemantics(label),
                button: true,
                excludeSemantics: true,
                onTap: onEdit,
                child: InkWell(
                  key: const Key('edit.tile.number'),
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSizes.tilePadding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // « 8 · immeuble » shrinks rather than being cut when
                      // the column is narrow.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tile.isBuilding
                              ? l10n.editBuildingTile(label)
                              : label,
                          maxLines: 1,
                          style: AppTextStyles.editTileNumber.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('edit.tile.remove'),
              tooltip: l10n.removeNumberSemantics(label),
              onPressed: onRemove,
              color: colors.accent,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// « + numéros », the outlined button closing a column.
final class _AddNumbersButton extends StatelessWidget {
  const _AddNumbersButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Semantics(
      label: l10n.addNumbersTitle,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: colors.ground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.tileRadius),
          side: BorderSide(color: colors.ink, width: AppSizes.borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              l10n.addNumbersButton,
              style: AppTextStyles.compactButton.copyWith(color: colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
