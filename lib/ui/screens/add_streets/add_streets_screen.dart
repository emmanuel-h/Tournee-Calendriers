import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/size_reporter.dart';
import 'package:tournee_calendriers/ui/components/street_card_sheet.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/map/tournee_map.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The two ways of « Ajouter des rues ».
enum AddStreetsTab { map, list }

/// « Ajouter des rues » while a tournée is open (PLAN §5.4, Pick and
/// AddList mockups): the tabs « Carte | Liste ».
///
/// « Carte » (the default) is the tournée's map, opened on its communes,
/// with the search box and « Saisir une rue à la main » above it: a tap on
/// a road, or a street picked among the search results, shows its street
/// card, which adds it or takes it. « Liste » is the checklist of the
/// communes' streets ([ImportList]).
///
/// Only the tab shown is built: the map follows the streets only while it
/// shows.
final class AddStreetsScreen extends StatefulWidget {
  const AddStreetsScreen({super.key, this.initialTab = AddStreetsTab.map});

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

/// The search box, « Saisir une rue à la main », and the tournée's map
/// with the street card over it (Pick mockup).
///
/// A `ConsumerStatefulWidget`: the search text and the card's height
/// belong to this tab only.
final class _MapTab extends ConsumerStatefulWidget {
  const _MapTab();

  @override
  ConsumerState<_MapTab> createState() => _MapTabState();
}

final class _MapTabState extends ConsumerState<_MapTab> {
  final _search = TextEditingController();

  /// How tall the street card is, so the map keeps clear of it.
  var _cardHeight = 0.0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(addStreetsMapProvider);
    // `ref.read` for the intents: they are sent, never watched.
    final map = ref.read(addStreetsMapProvider.notifier);
    final showMap = ref.watch(tourneeMapViewProvider);
    final card = state.card;
    // The back gesture closes the card first, then the screen.
    return PopScope(
      canPop: card == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) map.closeCard();
      },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                _SearchBox(
                  controller: _search,
                  onSubmitted: (text) => unawaited(map.search(text)),
                  onCleared: () {
                    _search.clear();
                    map.clearSearch();
                  },
                ),
                OutlinedButton.icon(
                  key: const Key('addStreets.manual'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                    textStyle: AppTextStyles.rowCount,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.addStreetsManual),
                  onPressed: () => context.push(AppRoutes.manualStreet),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: showMap(
                      TourneeMap(
                        key: const Key('addStreets.map'),
                        layers: state.layers,
                        area: state.area,
                        selectedRoad: state.selectedRoad,
                        selectedPoint: state.selectedPoint,
                        onMapTapped: (point) {
                          FocusScope.of(context).unfocus();
                          unawaited(map.tapMap(point));
                        },
                        onStreetTapped: (street) {
                          FocusScope.of(context).unfocus();
                          map.tapStreet(street);
                        },
                        padding: EdgeInsets.only(
                          bottom: card == null ? 0 : _cardHeight,
                        ),
                      ),
                    ),
                  ),
                  if (state.search is! NoStreetSearch)
                    Positioned(
                      top: 0,
                      left: AppSizes.gutter,
                      right: AppSizes.gutter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              constraints.maxHeight *
                              AppSizes.searchResultsShare,
                        ),
                        child: _SearchResults(
                          search: state.search,
                          onPick: (street) {
                            FocusScope.of(context).unfocus();
                            unawaited(map.pick(street));
                          },
                        ),
                      ),
                    ),
                  if (card != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizeReporter(
                        onHeight: (height) {
                          if (mounted) setState(() => _cardHeight = height);
                        },
                        child: StreetCardSheet(
                          card: card,
                          onAdd: (assignToMe) =>
                              unawaited(map.add(assignToMe: assignToMe)),
                          onTake: () => unawaited(map.take()),
                          onRelease: () => unawaited(map.release()),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Rechercher une rue »: a white pill with a magnifier; the keyboard's
/// search key asks the BAN, ✕ empties it.
final class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onSubmitted,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final pill = OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(AppSizes.searchRadius),
      ),
      borderSide: BorderSide(color: colors.line, width: AppSizes.borderWidth),
    );
    return TextField(
      key: const Key('addStreets.search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      style: AppTextStyles.body.copyWith(color: colors.ink),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: l10n.addStreetsSearchHint,
        hintStyle: AppTextStyles.body.copyWith(color: colors.muted),
        prefixIcon: Icon(Icons.search, color: colors.muted),
        // `ListenableBuilder`: only the ✕ follows the text typed.
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  key: const Key('addStreets.search.clear'),
                  tooltip: l10n.addStreetsSearchClear,
                  icon: Icon(Icons.close, color: colors.muted),
                  onPressed: onCleared,
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
        enabledBorder: pill,
        focusedBorder: pill.copyWith(
          borderSide: BorderSide(
            color: colors.ink,
            width: AppSizes.borderWidth,
          ),
        ),
      ),
    );
  }
}

/// The search's results over the map: the streets found (a tap picks
/// one), or why there are none.
final class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.search, required this.onPick});

  final StreetSearch search;
  final ValueChanged<BanStreetId> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    Widget note(String text) => Padding(
      key: const Key('addStreets.search.note'),
      padding: const EdgeInsets.all(AppSizes.fieldPadding),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(color: colors.muted),
      ),
    );
    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: colors.ink,
      borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      clipBehavior: Clip.antiAlias,
      child: switch (search) {
        NoStreetSearch() => const SizedBox.shrink(),
        SearchingStreets() => const Padding(
          padding: EdgeInsets.all(AppSizes.fieldPadding),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        StreetSearchFailed(problem: LookUpProblem.noNetwork) => note(
          l10n.addStreetsSearchNoNetwork,
        ),
        StreetSearchFailed() => note(l10n.addStreetsSearchError),
        StreetsFound(:final streets) when streets.isEmpty => note(
          l10n.addStreetsSearchNone,
        ),
        StreetsFound(:final streets) => ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: streets.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: colors.divider),
          itemBuilder: (context, index) {
            final street = streets[index];
            return InkWell(
              key: ValueKey('addStreets.found.${street.id.value}'),
              onTap: () => onPick(street.id),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.choiceRowHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.fieldPadding,
                  vertical: 8,
                ),
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      street.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      street.commune,
                      style: AppTextStyles.small.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      },
    );
  }
}
