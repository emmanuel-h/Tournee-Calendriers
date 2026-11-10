import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/add_progress.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/size_reporter.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/map/sector_map.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The two ways of « Ajouter des rues ».
enum AddStreetsTab { map, list }

/// « Ajouter des rues », opened from Secteur (PLAN §5.4, §5.14, Pick and
/// AddList mockups): the tabs « Carte | Liste ».
///
/// « Carte » (the default) is the secteur's map, opened on its communes,
/// with the search box above it: a tap on a road, or a street picked among
/// the search results, ticks it, and the selection sheet at the bottom adds
/// every street ticked at once. « Liste » is the checklist of the
/// communes' streets ([ImportList]).
///
/// Only the tab shown is built: the map runs only while it shows. The
/// ticks of « Carte » stay while « Liste » shows (see [build]).
final class AddStreetsScreen extends ConsumerStatefulWidget {
  const AddStreetsScreen({super.key, this.initialTab = AddStreetsTab.map});

  final AddStreetsTab initialTab;

  @override
  ConsumerState<AddStreetsScreen> createState() => _AddStreetsScreenState();
}

final class _AddStreetsScreenState extends ConsumerState<AddStreetsScreen> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // An `autoDispose` provider lives while someone listens to it: this
    // listener, which does nothing, keeps the streets ticked on « Carte »
    // while « Liste » shows, until the screen closes.
    ref.listen(addStreetsMapProvider, (_, _) {});
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CloseIconButton(
          tooltip: l10n.gridClose,
          // `maybePop`, unlike `pop`, asks the tab's `PopScope` first: no
          // way back while streets are being written.
          onPressed: () => Navigator.of(context).maybePop(),
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

/// The search box over the secteur's map, and the selection sheet at the
/// bottom (Pick mockup).
///
/// A `ConsumerStatefulWidget`: the search text, the sheet's height and
/// whether it is folded belong to this tab only.
final class _MapTab extends ConsumerStatefulWidget {
  const _MapTab();

  @override
  ConsumerState<_MapTab> createState() => _MapTabState();
}

final class _MapTabState extends ConsumerState<_MapTab> {
  final _search = TextEditingController();

  /// How tall the selection sheet is, so the map keeps clear of it.
  var _sheetHeight = 0.0;

  /// The sheet shows only its title (its handle dragged down).
  var _folded = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addStreetsMapProvider);
    // `ref.read` for the intents: they are sent, never watched.
    final map = ref.read(addStreetsMapProvider.notifier);
    final showMap = ref.watch(sectorMapViewProvider);
    return PopScope(
      // No way back while streets are being written.
      canPop: !state.adding,
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
            child: _SearchBox(
              controller: _search,
              onSubmitted: (text) => unawaited(map.search(text)),
              onCleared: () {
                _search.clear();
                map.clearSearch();
              },
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: showMap(
                      SectorMap(
                        key: const Key('addStreets.map'),
                        layers: state.layers,
                        area: state.area,
                        selectedPoint: state.lookingAt,
                        pickedRoads: state.pickedRoads,
                        onMapTapped: (point) {
                          FocusScope.of(context).unfocus();
                          unawaited(_answer(map.tapMap(point)));
                        },
                        onStreetTapped: (street) {
                          FocusScope.of(context).unfocus();
                          _say(map.tapStreet(street));
                        },
                        onPickTapped: map.untick,
                        padding: EdgeInsets.only(bottom: _sheetHeight),
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
                            unawaited(_answer(map.pick(street)));
                          },
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizeReporter(
                      onHeight: (height) {
                        if (mounted) setState(() => _sheetHeight = height);
                      },
                      child: _SelectionSheet(
                        state: state,
                        folded: _folded,
                        maxListHeight: math.min(
                          AppSizes.pickedRowHeight * AppSizes.pickedRowsShown,
                          constraints.maxHeight * AppSizes.selectionListShare,
                        ),
                        onFold: (folded) => setState(() => _folded = folded),
                        onAdd: () => unawaited(_add()),
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

  Future<void> _answer(Future<TapAnswer> answer) async => _say(await answer);

  /// What a tap had to say, in a snackbar: a street already in the
  /// secteur, or why none could be looked up, with « Saisir à la main ».
  void _say(TapAnswer answer) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (answer) {
      case NothingToSay():
        break;
      case AlreadyInSector(:final name):
        showMessageSnackBar(messenger, message: l10n.addStreetsAlreadyIn(name));
      case LookUpFailed(:final problem):
        // Read now: the action may be tapped once this tab is gone (the
        // « Liste » tab shown), when its context can no longer be used.
        final router = GoRouter.of(context);
        showActionSnackBar(
          messenger,
          message: switch (problem) {
            LookUpProblem.noNetwork => l10n.addStreetsNoNetwork,
            LookUpProblem.noStreetHere => l10n.addStreetsNoStreetHere,
            LookUpProblem.serviceError => l10n.addStreetsServiceError,
          },
          actionLabel: l10n.addStreetsManualAction,
          onAction: () => router.push(AppRoutes.manualStreet).ignore(),
        );
    }
  }

  /// « Ajouter N rues »: once every street ticked is in the secteur, back
  /// to Secteur with « 3 rues ajoutées au secteur ». Otherwise the sheet
  /// says why and keeps the ones that failed.
  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    // The app's messenger: the snackbar shows on Secteur, once back there.
    final messenger = ScaffoldMessenger.of(context);
    final added = await ref.read(addStreetsMapProvider.notifier).add();
    if (added == null || !mounted) return;
    showMessageSnackBar(messenger, message: l10n.addDone(added));
    context.pop();
  }
}

/// The white sheet at the bottom of the map (Pick mockup): « Touchez les
/// rues à ajouter. » with nothing ticked; otherwise « 2 rues
/// sélectionnées », « Tout décocher », a row per street with its ✕, why
/// some failed, « Ajouter 2 rues » (« Ajout en cours… 2/3 » meanwhile).
/// « Rue absente de la carte ? Saisir à la main » closes it in both cases.
///
/// Dragging the handle down (or tapping it) leaves only the title, so more
/// of the map shows; up (or a tap) brings the rows back.
final class _SelectionSheet extends ConsumerWidget {
  const _SelectionSheet({
    required this.state,
    required this.folded,
    required this.maxListHeight,
    required this.onFold,
    required this.onAdd,
  });

  final AddStreetsMapState state;
  final bool folded;

  /// The rows scroll past this height.
  final double maxListHeight;

  final ValueChanged<bool> onFold;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final map = ref.read(addStreetsMapProvider.notifier);
    final picked = state.picked;
    final looking = state.lookingAt != null;
    final handle = Center(
      child: Container(
        width: AppSizes.dragHandleWidth,
        height: AppSizes.dragHandleHeight,
        decoration: BoxDecoration(
          color: colors.line,
          borderRadius: BorderRadius.circular(AppSizes.dragHandleHeight / 2),
        ),
      ),
    );
    final manualLink = TextButton(
      key: const Key('addStreets.manual'),
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
        textStyle: AppTextStyles.rowCount,
      ),
      onPressed: () => context.push(AppRoutes.manualStreet),
      child: Text(l10n.addStreetsManualLink, textAlign: TextAlign.center),
    );
    final loading = Row(
      key: const Key('addStreets.lookingUp'),
      spacing: 12,
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        Flexible(
          child: Text(
            l10n.addStreetsLookingUp,
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ),
      ],
    );
    return Material(
      key: const Key('addStreets.sheet'),
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.ink,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.sheetRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: picked.isEmpty
              ? [
                  handle,
                  if (looking) loading,
                  Text(
                    l10n.addStreetsPickHint,
                    key: const Key('addStreets.hint'),
                    style: AppTextStyles.body.copyWith(color: colors.muted),
                  ),
                  manualLink,
                ]
              : [
                  // The handle and the title fold the sheet. A tap there
                  // does too; screen readers have it as a button.
                  Semantics(
                    button: true,
                    onTapHint: folded
                        ? l10n.addStreetsUnfold
                        : l10n.addStreetsFold,
                    child: GestureDetector(
                      key: const Key('addStreets.sheet.handle'),
                      // `opaque`: the empty room around the handle answers
                      // too.
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onFold(!folded),
                      onVerticalDragEnd: (details) {
                        final speed = details.primaryVelocity ?? 0;
                        if (speed != 0) onFold(speed > 0);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          handle,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.addStreetsPicked(picked.length),
                                  key: const Key('addStreets.picked'),
                                  style: AppTextStyles.listHeader.copyWith(
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const Key('addStreets.untickAll'),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.muted,
                                  minimumSize: const Size(
                                    AppSizes.minTapTarget,
                                    AppSizes.minTapTarget,
                                  ),
                                  textStyle: AppTextStyles.pill.copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                onPressed: state.adding ? null : map.untickAll,
                                child: Text(l10n.uncheckAll),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!folded) ...[
                    if (looking) loading,
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxListHeight),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: colors.divider),
                          ),
                        ),
                        child: ListView(
                          key: const Key('addStreets.rows'),
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            for (final street in picked)
                              _PickedRow(
                                street: street,
                                onUntick: state.adding
                                    ? null
                                    : () => map.untick(street.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (state.run case AddFailed(:final failed))
                      Text(
                        l10n.addStreetsAddFailed(failed),
                        key: const Key('addStreets.failed'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: colors.accent,
                        ),
                      ),
                    if (state.run case AddRunning(:final done, :final total))
                      AddProgress(
                        key: const Key('addStreets.progress'),
                        done: done,
                        total: total,
                      )
                    else
                      PrimaryButton(
                        key: const Key('addStreets.add'),
                        label: l10n.addButton(picked.length),
                        onPressed: onAdd,
                      ),
                    manualLink,
                  ],
                ],
        ),
      ),
    );
  }
}

/// A street ticked: « Rue Pierre Morin » over « Villefranche-sur-Saône ·
/// 19 numéros », and the ✕ that unticks it (« Retirer Rue Pierre Morin »).
final class _PickedRow extends StatelessWidget {
  const _PickedRow({required this.street, required this.onUntick});

  final PickedStreetRow street;

  /// Null while the streets are being added.
  final VoidCallback? onUntick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      key: ValueKey('addStreets.row.${street.id.value}'),
      constraints: const BoxConstraints(minHeight: AppSizes.pickedRowHeight),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
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
                  l10n.addStreetsPickedFacts(
                    street.commune,
                    l10n.addStreetsNumbers(street.numberCount),
                  ),
                  style: AppTextStyles.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('addStreets.untick.${street.id.value}'),
            tooltip: l10n.addStreetsUntick(street.name),
            icon: Icon(Icons.close, color: colors.ink),
            onPressed: onUntick,
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
