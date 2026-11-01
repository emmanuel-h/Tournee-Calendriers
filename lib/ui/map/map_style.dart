import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/ui/map/map_geojson.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// The background map: OpenFreeMap's « liberty » style, chosen in the map
/// spike (docs/spikes/map.md): free, no key, OpenStreetMap data, and its
/// attribution comes with the tiles (the ⓘ button of the map).
const openFreeMapStyle = 'https://tiles.openfreemap.org/styles/liberty';

/// The first label layer of the liberty style. The street lines are drawn
/// under it, so the names of the streets stay readable on top of their
/// colour; the house dots stay above everything.
const styleLabelsLayer = 'waterway_line_label';

/// The layer of the style to draw the street lines under: [styleLabelsLayer]
/// when the style has it, otherwise none (on top), so another style still
/// shows our lines.
String? lineLayersBelow(Iterable<Object?> styleLayerIds) =>
    styleLayerIds.contains(styleLabelsLayer) ? styleLabelsLayer : null;

/// The sources and layers our map adds over the style. Prefixed so they
/// never clash with a layer of the style.
abstract final class MapIds {
  static const streetsSource = 'tc-streets';
  static const housesSource = 'tc-houses';
  static const selectedSource = 'tc-selected';
  static const selectedPointSource = 'tc-selected-point';

  static const streetLines = 'tc-street-lines';
  static const freeStreetCasing = 'tc-free-street-casing';
  static const freeStreetLines = 'tc-free-street-lines';
  static const selectedCasing = 'tc-selected-casing';
  static const selectedCore = 'tc-selected-core';
  static const selectedPointHalo = 'tc-selected-point-halo';
  static const selectedPointDot = 'tc-selected-point-dot';
  static const houseDots = 'tc-house-dots';
}

/// The name of the picture of a house dot with [status], added to the map
/// by `addImage` (see `house_dot_image.dart`).
String houseDotImage(HouseDotStatus status) => 'tc-house-${status.name}';

/// The street a tap on a feature of [layerId] names, or null when the layer
/// is not one of the tournée's streets (a layer of the style, or the road
/// picked on « Ajouter des rues »). Every street feature carries its
/// street's id as its own (see `map_geojson.dart`).
StreetId? tappedStreet(String layerId, String featureId) => switch (layerId) {
  MapIds.streetLines ||
  MapIds.freeStreetCasing ||
  MapIds.freeStreetLines ||
  MapIds.houseDots => StreetId(featureId),
  _ => null,
};

/// One layer our map adds: [properties] drawn from [source], under the
/// style's labels when [belowLabels], from [minZoom] up, only the features
/// matching [filter], answering taps when [interactive].
final class MapLayerSpec {
  const MapLayerSpec({
    required this.id,
    required this.source,
    required this.properties,
    this.filter,
    this.minZoom,
    required this.belowLabels,
    required this.interactive,
  });

  final String id;
  final String source;
  final LayerProperties properties;

  /// A MapLibre filter expression; null keeps every feature.
  final List<Object>? filter;
  final double? minZoom;
  final bool belowLabels;
  final bool interactive;
}

/// Every layer the map adds, bottom to top: the streets (solid, then the
/// « libre » ones, dark grey dashes on a white casing), the road picked on
/// « Ajouter des rues » (dark casing, white core, mockups README) and the
/// point tapped (a dark dot in a faint halo, Pick mockup), then the house
/// dots from street zoom (PLAN §5.3). Colours are the map tokens of
/// [colors].
List<MapLayerSpec> tourneeMapLayers(AppColors colors) {
  final isFree = ['==', _level, ProgressLevel.free.name];
  return [
    MapLayerSpec(
      id: MapIds.streetLines,
      source: MapIds.streetsSource,
      properties: LineLayerProperties(
        lineColor: _levelColor(colors),
        lineWidth: _streetWidth,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: ['!', isFree],
      belowLabels: true,
      interactive: true,
    ),
    // A white casing under the dashes, wider than them, so a « libre »
    // street stands out from the base map's grey roads (mockups README).
    // It is also the fallback line: some GPUs (the emulator's at least)
    // draw no dashed line at all, and a « libre » street must never vanish
    // from the map. Opaque, so it shows on its own when the dashes do not.
    MapLayerSpec(
      id: MapIds.freeStreetCasing,
      source: MapIds.streetsSource,
      properties: LineLayerProperties(
        lineColor: colors.mapStreetFreeCasing.toHexStringRGB(),
        lineWidth: _byZoom(const {12: 6, 16: 11, 19: 16}),
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: isFree,
      belowLabels: true,
      interactive: true,
    ),
    MapLayerSpec(
      id: MapIds.freeStreetLines,
      source: MapIds.streetsSource,
      properties: LineLayerProperties(
        // Only « libre » streets reach this layer (the filter): their
        // colour needs no `match` on the level.
        lineColor: streetLineColor(ProgressLevel.free, colors).toHexStringRGB(),
        lineWidth: _streetWidth,
        // Dash and gap in line widths, so the pattern keeps its proportions
        // at every zoom: 11.2 px dash, 8.4 px gap at width 7, as the
        // mockups draw « libre ».
        lineDasharray: const [1.6, 1.2],
        lineJoin: 'round',
      ),
      filter: isFree,
      belowLabels: true,
      interactive: true,
    ),
    MapLayerSpec(
      id: MapIds.selectedCasing,
      source: MapIds.selectedSource,
      properties: LineLayerProperties(
        lineColor: colors.mapSelectedCasing.toHexStringRGB(),
        lineWidth: _byZoom(const {12: 8, 16: 16, 19: 24}),
        lineCap: 'round',
        lineJoin: 'round',
      ),
      belowLabels: false,
      // Not a street of the tournée: a tap on it goes on to the map, which
      // looks up the road under the finger again.
      interactive: false,
    ),
    MapLayerSpec(
      id: MapIds.selectedCore,
      source: MapIds.selectedSource,
      properties: LineLayerProperties(
        lineColor: colors.mapSelectedCore.toHexStringRGB(),
        lineWidth: _byZoom(const {12: 3, 16: 6, 19: 10}),
        lineCap: 'round',
        lineJoin: 'round',
      ),
      belowLabels: false,
      interactive: false,
    ),
    MapLayerSpec(
      id: MapIds.selectedPointHalo,
      source: MapIds.selectedPointSource,
      properties: CircleLayerProperties(
        circleColor: colors.mapSelectedCasing.toHexStringRGB(),
        circleRadius: 18,
        circleOpacity: 0.12,
      ),
      belowLabels: false,
      interactive: false,
    ),
    MapLayerSpec(
      id: MapIds.selectedPointDot,
      source: MapIds.selectedPointSource,
      properties: CircleLayerProperties(
        circleColor: colors.mapSelectedCasing.toHexStringRGB(),
        circleRadius: 6,
      ),
      belowLabels: false,
      interactive: false,
    ),
    MapLayerSpec(
      id: MapIds.houseDots,
      source: MapIds.housesSource,
      properties: SymbolLayerProperties(
        iconImage: [
          'match',
          ['get', statusProperty],
          for (final status in HouseDotStatus.values) ...[
            status.name,
            houseDotImage(status),
          ],
          houseDotImage(HouseDotStatus.toDo),
        ],
        // The pictures are drawn at their full size for street zoom 18;
        // smaller further out, where houses sit closer on screen.
        iconSize: _byZoom(const {16: 0.6, 18: 1}),
        // Every dot shows, even over another: a hidden house would read as
        // no house at all.
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        textField: ['get', numberProperty],
        textFont: const ['Noto Sans Bold'],
        textSize: 12,
        textAnchor: 'top',
        textOffset: const [0, 1.3],
        textColor: colors.ink.toHexStringRGB(),
        textHaloColor: colors.surface.toHexStringRGB(),
        textHaloWidth: 1.5,
        // A number that would overlap another is left out, its dot is not.
        textOptional: true,
      ),
      minZoom: MapLayers.houseDotsMinZoom.toDouble(),
      belowLabels: false,
      interactive: true,
    ),
  ];
}

const _level = ['get', levelProperty];

/// The width of a street line, taken or « libre », by zoom.
final _streetWidth = _byZoom(const {12: 3, 16: 7, 19: 12});

/// A line's colour from its level: the map tokens of the mockups README.
List<Object> _levelColor(AppColors colors) => [
  'match',
  _level,
  for (final level in ProgressLevel.values) ...[
    level.name,
    streetLineColor(level, colors).toHexStringRGB(),
  ],
  colors.mapStreetFree.toHexStringRGB(),
];

/// The colour of a street line at [level], from the map tokens of
/// [colors]; the legend under the map draws its samples with it too.
Color streetLineColor(ProgressLevel level, AppColors colors) => switch (level) {
  ProgressLevel.free => colors.mapStreetFree,
  ProgressLevel.toDo => colors.mapStreetToDo,
  ProgressLevel.partial => colors.mapStreetPartial,
  ProgressLevel.done => colors.mapStreetDone,
};

/// A value that grows with the zoom, in straight lines between the
/// [stops] (zoom → value), constant beyond the first and last.
List<Object> _byZoom(Map<int, num> stops) => [
  'interpolate',
  ['linear'],
  ['zoom'],
  for (final MapEntry(key: zoom, value: value) in stops.entries) ...[
    zoom,
    value,
  ],
];
