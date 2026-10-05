import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The choices of « Gérer l'immeuble » under the grid (PLAN §5.7).
enum BuildingAction {
  /// « Modifier les étages »: « Décrire l'immeuble », prefilled.
  editFloors,

  /// « Ajuster les portes »: a door more or less, a door renamed.
  adjustDoors,

  /// « Redevenir une maison »: the doors go (asked first when marked).
  backToHouse,
}

/// Opens « Gérer l'immeuble » over the grid and returns the choice, or null
/// when the menu is closed without one.
///
/// A bottom sheet rather than a drop-down menu: every other choice of the
/// app opens as a sheet, its rows are 56 dp tall for a gloved thumb, and
/// screen readers read it as a dialog with a title. It closes before the
/// choice runs, so no two sheets stack on the grid.
Future<BuildingAction?> showBuildingMenu(BuildContext context) =>
    showAppBottomSheet<BuildingAction>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SheetScaffold(
          title: l10n.manageBuilding,
          spacing: 0,
          children: [
            const SizedBox(height: 8),
            for (final action in BuildingAction.values)
              _MenuRow(
                key: ValueKey('buildingMenu.${action.name}'),
                label: switch (action) {
                  BuildingAction.editFloors => l10n.editFloors,
                  BuildingAction.adjustDoors => l10n.adjustDoorsAction,
                  BuildingAction.backToHouse => l10n.backToHouseAction,
                },
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        );
      },
    );

/// One choice: its label on a row of 56 dp, over a thin divider.
final class _MenuRow extends StatelessWidget {
  const _MenuRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.choiceRowHeight,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
