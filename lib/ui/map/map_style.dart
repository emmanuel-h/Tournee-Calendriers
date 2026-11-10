import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/ui/map/map_geojson.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

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
  static const pickedSource = 'tc-picked';
  static const pickedMarksSource = 'tc-picked-marks';
  static const zoneSource = 'tc-zone';

  static const streetLines = 'tc-street-lines';
  static const selectedCasing = 'tc-selected-casing';
  static const selectedCore = 'tc-selected-core';
  static const selectedPointHalo = 'tc-selected-point-halo';
  static const selectedPointDot = 'tc-selected-point-dot';
  static const pickedCasing = 'tc-picked-casing';
  static const pickedCore = 'tc-picked-core';
  static const pickedMarks = 'tc-picked-mark-discs';
  static const pickedTicks = 'tc-picked-mark-ticks';
  static const houseDots = 'tc-house-dots';
  static const zoneShade = 'tc-zone-shade';
  static const zoneEdge = 'tc-zone-edge';
  static const zoneHandle = 'tc-zone-handle';
}

/// The name of the picture of a house dot with [status], added to the map
/// by `addImage` (see `house_dot_image.dart`).
String houseDotImage(HouseDotStatus status) => 'tc-house-${status.name}';

/// The name of the ✓ disc of a road ticked on « Ajouter des rues », added
/// to the map by `addImage` (see `house_dot_image.dart`).
const pickedMarkImage = 'tc-picked-mark';

/// The street a tap on a feature of [layerId] names, or null when the layer
/// is not one of the tournée's streets (a layer of the style, or the road
/// picked on « Ajouter des rues »). Every street feature carries its
/// street's id as its own (see `map_geojson.dart`).
StreetId? tappedStreet(String layerId, String featureId) => switch (layerId) {
  MapIds.streetLines || MapIds.houseDots => StreetId(featureId),
  _ => null,
};

/// The ticked street a tap on a feature of [layerId] names: its road or
/// its ✓ disc on « Ajouter des rues » (PLAN §5.14), whose features carry
/// the street's BAN id as their own; null for any other layer.
BanStreetId? tappedPick(String layerId, String featureId) => switch (layerId) {
  MapIds.pickedCasing || MapIds.pickedMarks => BanStreetId(featureId),
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

/// Every layer the map adds, bottom to top: the streets, the street picked
/// on Accueil and the roads ticked on « Ajouter des rues » (dark casing,
/// white core, mockups README), the point being looked up (a dark dot in a
/// faint halo, Pick mockup), the house dots from street zoom (PLAN §5.3),
/// then the ✓ discs of the ticked roads (a dark disc, the ✓ picture on it),
/// and the zone drawn on « Ajouter des rues » over everything (the map
/// dimmed around it, its dashed edge, its handle; fill, line and circle
/// layers, which every renderer draws). Colours are the map tokens of
/// [colors].
List<MapLayerSpec> sectorMapLayers(AppColors colors) => [
  MapLayerSpec(
    id: MapIds.streetLines,
    source: MapIds.streetsSource,
    properties: LineLayerProperties(
      lineColor: _levelColor(colors),
      lineWidth: _streetWidth,
      lineCap: 'round',
      lineJoin: 'round',
    ),
    belowLabels: true,
    interactive: true,
  ),
  MapLayerSpec(
    id: MapIds.selectedCasing,
    source: MapIds.selectedSource,
    properties: _casing(colors),
    belowLabels: false,
    // Not a street of the tournée: a tap on it goes on to the map, which
    // looks up the road under the finger again.
    interactive: false,
  ),
  MapLayerSpec(
    id: MapIds.selectedCore,
    source: MapIds.selectedSource,
    properties: _core(colors),
    belowLabels: false,
    interactive: false,
  ),
  MapLayerSpec(
    id: MapIds.pickedCasing,
    source: MapIds.pickedSource,
    properties: _casing(colors),
    belowLabels: false,
    // A tap on a ticked road unticks it, without asking the BAN again.
    interactive: true,
  ),
  MapLayerSpec(
    id: MapIds.pickedCore,
    source: MapIds.pickedSource,
    properties: _core(colors),
    belowLabels: false,
    // The casing under it is wider: a tap on the core reaches it.
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
  // The ✓ disc is two layers. The disc is a circle, which every renderer
  // draws (the emulator's software renderer draws no symbol layer at all,
  // not even the style's street names); the ✓ picture over it is the same
  // disc with its ✓, as the house dots are drawn.
  MapLayerSpec(
    id: MapIds.pickedMarks,
    source: MapIds.pickedMarksSource,
    properties: CircleLayerProperties(
      circleColor: colors.mapSelectedCasing.toHexStringRGB(),
      circleRadius: AppSizes.houseDot / 2,
    ),
    belowLabels: false,
    interactive: true,
  ),
  const MapLayerSpec(
    id: MapIds.pickedTicks,
    source: MapIds.pickedMarksSource,
    properties: SymbolLayerProperties(
      iconImage: pickedMarkImage,
      // A ✓ hidden behind a label would read as a street not ticked.
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
    ),
    belowLabels: false,
    // The disc under it answers the tap.
    interactive: false,
  ),
  MapLayerSpec(
    id: MapIds.zoneShade,
    source: MapIds.zoneSource,
    properties: FillLayerProperties(
      fillColor: colors.mapSelectedCasing.toHexStringRGB(),
      fillOpacity: AppSizes.zoneShadeOpacity,
    ),
    filter: _zonePart(ZonePart.shade),
    belowLabels: false,
    // Taps go through to the map: a road may be tapped in « Zone » too.
    interactive: false,
  ),
  MapLayerSpec(
    id: MapIds.zoneEdge,
    source: MapIds.zoneSource,
    properties: LineLayerProperties(
      lineColor: colors.mapSelectedCasing.toHexStringRGB(),
      lineWidth: AppSizes.zoneEdgeWidth,
      // MapLibre counts dashes in line widths.
      lineDasharray: const [
        AppSizes.zoneDash / AppSizes.zoneEdgeWidth,
        AppSizes.zoneGap / AppSizes.zoneEdgeWidth,
      ],
    ),
    filter: _zonePart(ZonePart.edge),
    belowLabels: false,
    interactive: false,
  ),
  MapLayerSpec(
    id: MapIds.zoneHandle,
    source: MapIds.zoneSource,
    properties: CircleLayerProperties(
      circleColor: colors.mapSelectedCore.toHexStringRGB(),
      circleRadius: AppSizes.zoneHandleRadius,
      circleStrokeColor: colors.mapSelectedCasing.toHexStringRGB(),
      circleStrokeWidth: AppSizes.zoneEdgeWidth,
    ),
    filter: _zonePart(ZonePart.handle),
    belowLabels: false,
    // A drag from it resizes the zone (`ZoneDrawing`), not a tap.
    interactive: false,
  ),
];

/// The filter keeping the features of the zone's [part].
List<Object> _zonePart(ZonePart part) => [
  '==',
  ['get', zonePartProperty],
  part.name,
];

/// The dark casing of a road picked or ticked (mockups README).
LineLayerProperties _casing(AppColors colors) => LineLayerProperties(
  lineColor: colors.mapSelectedCasing.toHexStringRGB(),
  lineWidth: _byZoom(const {12: 8, 16: 16, 19: 24}),
  lineCap: 'round',
  lineJoin: 'round',
);

/// The white core over [_casing].
LineLayerProperties _core(AppColors colors) => LineLayerProperties(
  lineColor: colors.mapSelectedCore.toHexStringRGB(),
  lineWidth: _byZoom(const {12: 3, 16: 6, 19: 10}),
  lineCap: 'round',
  lineJoin: 'round',
);

const _level = ['get', levelProperty];

/// The width of a street line, by zoom.
final _streetWidth = _byZoom(const {12: 3, 16: 7, 19: 12});

/// A line's colour from its level: the map tokens of the mockups README.
List<Object> _levelColor(AppColors colors) => [
  'match',
  _level,
  for (final level in ProgressLevel.values) ...[
    level.name,
    streetLineColor(level, colors).toHexStringRGB(),
  ],
  // `match` needs a fallback, never used: every line has a level.
  colors.mapStreetToDo.toHexStringRGB(),
];

/// The colour of a street line at [level], from the map tokens of
/// [colors]; the legend under the map draws its samples with it too.
Color streetLineColor(ProgressLevel level, AppColors colors) => switch (level) {
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
