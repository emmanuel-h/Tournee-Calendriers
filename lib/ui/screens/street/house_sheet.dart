import 'package:flutter/material.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/building_icon.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/marks_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// How the Fiche maison was left, when it asks for what comes next.
enum HouseSheetExit {
  /// « Transformer en immeuble… »: the street screen opens « Décrire
  /// l'immeuble ».
  toBuilding,

  /// « Repassé, toujours personne »: the street screen makes the house
  /// « personne » with one more try, and offers « Annuler ».
  nobodyHomeAgain,

  /// « Annuler » of a sheet a tap opened (#81): the street screen undoes
  /// that tap, as the snackbar's « Annuler » would have.
  cancelTap,
}

/// Opens the Fiche maison of one house over the street screen (hold a
/// tile, PLAN §5.7, `docs/mockups/House.dc.html`; or a tap that made it
/// « Repasser », [openedByTap], `HouseComeBack.dc.html`). Returns how it was
/// left when the street screen has something to do next
/// ([HouseSheetExit]), null otherwise.
///
/// The sheet closes before the next one opens, rather than stacking two
/// sheets: the street screen then opens « Décrire l'immeuble ».
Future<HouseSheetExit?> showHouseSheet(
  BuildContext context,
  HouseSheetKey house, {
  bool openedByTap = false,
}) => showAppBottomSheet<HouseSheetExit>(
  context: context,
  builder: (_) => HouseSheet(house: house, openedByTap: openedByTap),
);

/// The Fiche maison: number and street, the status control, the tries with
/// « Repassé, toujours personne », « Quand repasser ? », and the last
/// change; then « Transformer en immeuble… » when held, « Annuler » and
/// « OK » when a tap opened it.
final class HouseSheet extends StatelessWidget {
  const HouseSheet({super.key, required this.house, this.openedByTap = false});

  final HouseSheetKey house;

  /// A tap made the house « Repasser » and opened the sheet by itself, to
  /// say when (#81).
  final bool openedByTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MarksSheet(
      provider: houseSheetProvider(house),
      name: 'house',
      goneMessage: l10n.houseGone,
      title: (state) => MarksSheetTitle(
        name: 'house',
        big: state.number.label,
        beside: state.streetName,
      ),
      // Not on a sheet a tap opened: the time is what it is for.
      action: openedByTap
          ? null
          : SecondaryButton(
              key: const Key('house.toBuilding'),
              label: l10n.transformToBuilding,
              compact: true,
              leading: const BuildingIcon(size: AppSizes.smallIcon),
              onPressed: () =>
                  Navigator.of(context).pop(HouseSheetExit.toBuilding),
            ),
      onNobodyHomeAgain: () =>
          Navigator.of(context).pop(HouseSheetExit.nobodyHomeAgain),
      onCancelTap: openedByTap
          ? () => Navigator.of(context).pop(HouseSheetExit.cancelTap)
          : null,
    );
  }
}
