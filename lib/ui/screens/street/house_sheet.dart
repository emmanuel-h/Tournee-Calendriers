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
}

/// Opens the Fiche maison of one house over the street screen (hold a
/// tile, PLAN §5.7, `docs/mockups/House.dc.html`). Returns
/// [HouseSheetExit.toBuilding] when it was left by « Transformer en
/// immeuble… », null otherwise.
///
/// The sheet closes before the next one opens, rather than stacking two
/// sheets: the street screen then opens « Décrire l'immeuble ».
Future<HouseSheetExit?> showHouseSheet(
  BuildContext context,
  HouseSheetKey house,
) => showAppBottomSheet<HouseSheetExit>(
  context: context,
  builder: (_) => HouseSheet(house: house),
);

/// The Fiche maison: number and street, the status control, « Repasser »
/// with its hint, « Transformer en immeuble… », and the last change.
final class HouseSheet extends StatelessWidget {
  const HouseSheet({super.key, required this.house});

  final HouseSheetKey house;

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
      action: SecondaryButton(
        key: const Key('house.toBuilding'),
        label: l10n.transformToBuilding,
        compact: true,
        leading: const BuildingIcon(size: AppSizes.smallIcon),
        onPressed: () => Navigator.of(context).pop(HouseSheetExit.toBuilding),
      ),
    );
  }
}
