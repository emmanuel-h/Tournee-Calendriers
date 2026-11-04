import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/presentation/home/home_notifier.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/size_reporter.dart';
import 'package:tournee_calendriers/ui/components/street_card_sheet.dart';
import 'package:tournee_calendriers/ui/map/map_legend.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/map/sector_map.dart';
import 'package:tournee_calendriers/ui/screens/home/home_panel.dart';
import 'package:tournee_calendriers/ui/screens/round/round_band.dart';
import 'package:tournee_calendriers/ui/screens/start/admin_visit_banner.dart';
import 'package:tournee_calendriers/ui/screens/start/start_app_bar.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The three heights the « Rues » panel rests at.
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

/// Accueil (PLAN §5.3, §5.14, RunStart and HomeZoom mockups), the start
/// screen while a secteur is open: the map of the secteur, its streets
/// coloured by progress and, from street zoom, its houses; the legend chip;
/// the « Rues » panel at the bottom, every street of the secteur. Its top
/// bar is the start screen's; during a tournée, the « En tournée » band
/// takes its place: no secteur switch, no Secteur, no ⚙ until it ends.
///
/// A tap on one of the secteur's streets on the map shows its street card
/// (§5.4) in place of the panel, its line lit up, with « Ouvrir ». A tap
/// elsewhere on the map, the ✕ or the back gesture brings the panel back.
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
    final showMap = ref.watch(sectorMapViewProvider);
    // `select`: the screen is built again when a tournée starts or ends,
    // not each time a don is added (the band follows those itself).
    final roundOn = ref.watch(
      roundProvider.select((round) => round is RoundOn),
    );
    // The back gesture closes the street card first, then leaves the app.
    return PopScope(
      canPop: state.card == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) home.unselect();
      },
      child: Scaffold(
        appBar: roundOn
            ? null
            : StartAppBar(
                sector: ref.watch(currentSectorProvider),
                showGallery: widget.showGallery,
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // In the top bar's place during a tournée, under the status bar.
            const RoundBand(),
            Expanded(
              // `top: false`: the top bar or the band keeps clear of the
              // status bar already.
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Only while an admin visits the open secteur.
                    const AdminVisitBanner(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final room = constraints.maxHeight;
                          final folded = homePanelFoldedHeight(
                            MediaQuery.textScalerOf(context),
                          );
                          final heights = {
                            PanelSize.folded: folded,
                            PanelSize.rest: max(
                              folded,
                              room * AppSizes.homePanelRestShare,
                            ),
                            PanelSize.full: max(folded, room),
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
                                  SectorMap(
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
                                              ((_dragHeight ??
                                                          heights[_size]!) -
                                                      dy)
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
                                      )
                                    : SizeReporter(
                                        onHeight: (height) {
                                          if (mounted) {
                                            setState(
                                              () => _cardHeight = height,
                                            );
                                          }
                                        },
                                        child: StreetCardSheet(
                                          key: const Key('home.selected'),
                                          card: card,
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
          ],
        ),
      ),
    );
  }

  void _zoomed(double zoom) {
    final houses = MapLayers.showsHouseDots(zoom);
    if (houses != _houses) setState(() => _houses = houses);
  }
}
