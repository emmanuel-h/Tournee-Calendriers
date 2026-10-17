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

  static const streetLines = 'tc-street-lines';
  static const freeStreetBase = 'tc-free-street-base';
  static const freeStreetLines = 'tc-free-street-lines';
  static const selectedCasing = 'tc-selected-casing';
  static const selectedCore = 'tc-selected-core';
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
  MapIds.freeStreetBase ||
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
/// « libre » ones, dashed over a faint solid line), the road picked on « Ajouter des rues » (dark
/// casing, white core, mockups README), then the house dots from street
/// zoom (PLAN §5.3). Colours are the map tokens of [colors].
List<MapLayerSpec> tourneeMapLayers(AppColors colors) {
  final isFree = ['==', _level, ProgressLevel.free.name];
  return [
    MapLayerSpec(
      id: MapIds.streetLines,
      source: MapIds.streetsSource,
      properties: LineLayerProperties(
        lineColor: _levelColor(colors),
        lineWidth: _byZoom(const {12: 3, 16: 7, 19: 12}),
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: ['!', isFree],
      belowLabels: true,
      interactive: true,
    ),
    // A faint solid line under the dashes: some GPUs (the emulator's at
    // least) draw no dashed line at all, and a « libre » street must never
    // vanish from the map. Where the dashes draw, it only tints their gaps.
    MapLayerSpec(
      id: MapIds.freeStreetBase,
      source: MapIds.streetsSource,
      properties: LineLayerProperties(
        lineColor: _levelColor(colors),
        lineWidth: _byZoom(const {12: 2.5, 16: 5, 19: 9}),
        lineOpacity: 0.35,
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
        lineColor: _levelColor(colors),
        lineWidth: _byZoom(const {12: 2.5, 16: 5, 19: 9}),
        // Dash and gap in line widths: 10 px dash, 8 px gap at width 5,
        // as the mockups draw « libre ».
        lineDasharray: const [2, 1.6],
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
