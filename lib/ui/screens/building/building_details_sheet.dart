import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/come_back_block.dart';
import 'package:tournee_calendriers/ui/components/come_back_time_picker.dart';
import 'package:tournee_calendriers/ui/components/sheet_number_title.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/last_change_text.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens the building's own « repasser » (« Repasser » under its grid,
/// PLAN §5.7): no status, its doors carry them.
Future<void> showBuildingDetailsSheet(
  BuildContext context,
  HouseSheetKey building,
) => showAppBottomSheet<void>(
  context: context,
  builder: (_) => BuildingDetailsSheet(building: building),
);

/// « 8 Rue des Lilas », the blue « ☐ ↻ Repasser » box and, once ticked,
/// « Quand repasser ? », then the last change. Every choice is stored as
/// soon as it is made.
///
/// A `ConsumerWidget`: the sheet keeps nothing of its own, every choice
/// goes to the notifier at once.
final class BuildingDetailsSheet extends ConsumerWidget {
  const BuildingDetailsSheet({super.key, required this.building});

  final HouseSheetKey building;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final provider = buildingDetailsProvider(building);
    // `ref.watch`: the sheet follows the building; it also keeps the
    // auto-disposed notifier alive while the sheet shows.
    final state = ref.watch(provider);
    // `ref.read`, in the callbacks only: reading the notifier asks for no
    // redraw.
    BuildingDetailsNotifier notifier() => ref.read(provider.notifier);
    return SheetScaffold(
      children: switch (state) {
        HouseSheetLoading() => const [],
        HouseSheetGone() => [
          Text(
            l10n.buildingGone,
            key: const ValueKey('building.gone'),
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
        HouseSheetShown() => [
          SheetNumberTitle(
            name: 'building',
            big: state.number.label,
            beside: state.streetName,
          ),
          ComeBackBlock(
            name: 'building',
            ticked: state.comeBack,
            onChanged: (on) => unawaited(notifier().setComeBack(on: on)),
            time: ComeBackTimePicker(
              name: 'building',
              time: state.comeBackTime,
              enabled: state.comeBack,
              onDay: (day) => unawaited(notifier().chooseComeBackDay(day)),
              onHour: (hour) => unawaited(notifier().chooseComeBackHour(hour)),
            ),
          ),
          if (state.lastChange case final change?)
            Text(
              lastChangeText(l10n, change),
              key: const ValueKey('building.lastChange'),
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: colors.muted),
            ),
        ],
      },
    );
  }
}
