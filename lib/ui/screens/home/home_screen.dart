import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/presentation/home/home_notifier.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/ui/components/size_reporter.dart';
import 'package:tournee_calendriers/ui/components/street_card_sheet.dart';
import 'package:tournee_calendriers/ui/map/map_legend.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/map/tournee_map.dart';
import 'package:tournee_calendriers/ui/screens/home/home_panel.dart';
import 'package:tournee_calendriers/ui/screens/start/admin_visit_banner.dart';
import 'package:tournee_calendriers/ui/screens/start/move_streets_card.dart';
import 'package:tournee_calendriers/ui/screens/start/start_app_bar.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The three heights the « Mes rues » panel rests at.
enum PanelSize {
  /// Only the handle and the totals.
  folded,

  /// Half the room: the map above, the first streets and « Ajouter des
  /// rues » below (Home mockup).
  rest,

  /// The whole room: the full list.
  full,
}

/// Where the panel goes when the finger leaves the handle at [height], at
/// [velocity] dp per second (down is positive): a quick flick goes one
/// step in its direction, a slow release to the nearest of [folded],
/// [rest] and [full].
PanelSize snapPanel(
  double height,
  double velocity, {
  required double folded,
  required double rest,
  required double full,
}) {
  const flick = 700.0;
  if (velocity < -flick) {
    return height < rest ? PanelSize.rest : PanelSize.full;
  }
  if (velocity > flick) {
    return height > rest ? PanelSize.rest : PanelSize.folded;
  }
  final distances = {
    PanelSize.folded: (height - folded).abs(),
    PanelSize.rest: (height - rest).abs(),
    PanelSize.full: (height - full).abs(),
  };
  return distances.entries
      .reduce((nearest, size) => size.value < nearest.value ? size : nearest)
      .key;
}

/// Accueil (PLAN §5.3, Home and HomeZoom mockups), the start screen while
/// a tournée is open: the map of the tournée, its streets coloured by
/// progress and, from street zoom, its houses; the legend chip; the
/// « Mes rues » panel at the bottom. Its top bar is the start screen's.
///
/// A tap on one of the tournée's streets on the map, or on a row under
/// « Autres rues de la tournée » (#93), shows its street card (§5.4) in
/// place of the panel, its line lit up: « Ouvrir », and « Me l'attribuer »
/// or « Ne plus la faire »; from a row, the map also goes to the street. A
/// tap elsewhere on the map, or the back gesture, brings the panel back.
/// Works offline: the streets come from the phone's copy, the map from the
/// tiles it keeps.
///
/// A `ConsumerStatefulWidget`: the panel's height and the legend's kind
/// belong to this screen only, so it keeps them in its `State`; what the
/// screen shows comes from `homeProvider`.
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.showGallery});

  /// Debug builds: an app-bar action opens the component gallery.
  final bool showGallery;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _size = PanelSize.rest;

  /// The panel's height while the handle is being dragged; null at rest.
  double? _dragHeight;

  /// The map shows the house dots: the legend explains them.
  var _houses = false;

  /// How tall the street card is, so the map keeps clear of it.
  var _cardHeight = 0.0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    // `ref.read` for the intents: they are sent, never watched.
    final home = ref.read(homeProvider.notifier);
    final showMap = ref.watch(tourneeMapViewProvider);
    // The back gesture closes the street card first, then leaves the app.
    return PopScope(
      canPop: state.card == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) home.unselect();
      },
      child: Scaffold(
        appBar: StartAppBar(
          tournee: ref.watch(currentTourneeProvider),
          showGallery: widget.showGallery,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only while an admin visits the open tournée.
              const AdminVisitBanner(),
              // The phone's streets offered to the open tournée (nothing
              // when there is none to offer).
              const MoveStreetsCard(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final room = constraints.maxHeight;
                    final heights = {
                      PanelSize.folded: AppSizes.homePanelFolded,
                      PanelSize.rest: max(
                        AppSizes.homePanelFolded,
                        room * AppSizes.homePanelRestShare,
                      ),
                      PanelSize.full: max(AppSizes.homePanelFolded, room),
                    };
                    final card = state.card;
                    // The room the panel (or the street card) takes over the
                    // map once at rest: « Me localiser », the attribution and
                    // the area the map fits stay clear of it.
                    final covered = card == null
                        ? heights[_size]!
                        : _cardHeight;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: showMap(
                            TourneeMap(
                              key: const Key('home.map'),
                              layers: state.layers,
                              area: state.area,
                              selectedRoad: state.selectedRoad,
                              onStreetTapped: home.select,
                              onMapTapped: (_) => home.unselect(),
                              onZoomChanged: _zoomed,
                              padding: EdgeInsets.only(bottom: covered),
                            ),
                          ),
                        ),
                        Positioned(
                          top: AppSizes.mapControlsMargin,
                          left: AppSizes.mapControlsMargin,
                          // Clear of « Me localiser », top right.
                          right:
                              AppSizes.mapControlsMargin * 2 +
                              AppSizes.mapButton,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: MapLegend(houses: _houses),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: card == null
                              ? HomePanel(
                                  key: const Key('home.panel'),
                                  state: state,
                                  height: _dragHeight ?? heights[_size]!,
                                  expanded: _size == PanelSize.full,
                                  onDrag: (dy) => setState(() {
                                    _dragHeight =
                                        ((_dragHeight ?? heights[_size]!) - dy)
                                            .clamp(
                                              heights[PanelSize.folded]!,
                                              heights[PanelSize.full]!,
                                            );
                                  }),
                                  onDragEnd: (velocity) => setState(() {
                                    _size = snapPanel(
                                      _dragHeight ?? heights[_size]!,
                                      velocity,
                                      folded: heights[PanelSize.folded]!,
                                      rest: heights[PanelSize.rest]!,
                                      full: heights[PanelSize.full]!,
                                    );
                                    _dragHeight = null;
                                  }),
                                  onToggle: () => setState(() {
                                    _size = _size == PanelSize.full
                                        ? PanelSize.rest
                                        : PanelSize.full;
                                  }),
                                  onOtherStreetTapped: home.focus,
                                )
                              : SizeReporter(
                                  onHeight: (height) {
                                    if (mounted) {
                                      setState(() => _cardHeight = height);
                                    }
                                  },
                                  child: StreetCardSheet(
                                    key: const Key('home.selected'),
                                    card: card,
                                    onTake: () => unawaited(home.take()),
                                    onRelease: () => unawaited(home.release()),
                                    onClose: home.unselect,
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _zoomed(double zoom) {
    final houses = MapLayers.showsHouseDots(zoom);
    if (houses != _houses) setState(() => _houses = houses);
  }
}
