import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/tournee_map.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The two ways of « Ajouter des rues ».
enum AddStreetsTab { map, list }

/// « Ajouter des rues » while a tournée is open (PLAN §5.4, Pick and
/// AddList mockups): the tabs « Carte | Liste ». « Carte » is the
/// tournée's map, opened on its communes (on its streets for a tournée
/// without commune); tapping a road to add it, the search and « Saisir une
/// rue à la main » come with #31. « Liste » is the checklist of the
/// communes' streets ([ImportList]).
///
/// Only the tab shown is built: the map follows the streets only while it
/// shows.
final class AddStreetsScreen extends StatefulWidget {
  const AddStreetsScreen({super.key, this.initialTab = AddStreetsTab.list});

  /// The list until the map can add a street (#31).
  final AddStreetsTab initialTab;

  @override
  State<AddStreetsScreen> createState() => _AddStreetsScreenState();
}

final class _AddStreetsScreenState extends State<AddStreetsScreen> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CloseIconButton(
          tooltip: l10n.gridClose,
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.addStreetsTitle),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                0,
                AppSizes.gutter,
                10,
              ),
              child: SegmentedChoice<AddStreetsTab>(
                key: const Key('addStreets.tabs'),
                groupLabel: l10n.addStreetsModes,
                height: AppSizes.minTapTarget,
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
                segments: [
                  Segment(
                    value: AddStreetsTab.map,
                    label: l10n.addStreetsMapTab,
                    key: const Key('addStreets.tab.map'),
                  ),
                  Segment(
                    value: AddStreetsTab.list,
                    label: l10n.addStreetsListTab,
                    key: const Key('addStreets.tab.list'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                AddStreetsTab.map => const _MapTab(),
                AddStreetsTab.list => const ImportList(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The tournée's map, opened on its communes.
final class _MapTab extends ConsumerWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addStreetsMapProvider);
    return TourneeMap(
      key: const Key('addStreets.map'),
      layers: state.layers,
      area: state.area,
    );
  }
}
