import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// The GeoJSON the map draws (RFC 7946), built from the domain's
/// [MapLayers] as plain maps and lists: MapLibre receives them over the
/// platform channel, which only carries JSON-like values.
///
/// Every feature of a street carries the street's id as its top-level `id`
/// (the line, and each of its houses' dots): that is the only thing a tap
/// on it reports (`onFeatureTapped`), and on a phone MapLibre reads no
/// other id (map spike, docs/spikes/map.md §3).

/// The property holding a street line's [StreetLine.level], by name
/// (`free`, `toDo`, `partial`, `done`): the style colours the line from it.
const levelProperty = 'level';

/// The property holding a house dot's [HouseDot.status], by name: the
/// style picks the dot's picture from it.
const statusProperty = 'status';

/// The property holding a house dot's number as written (« 3bis »): the
/// label under the dot.
const numberProperty = 'number';

/// One feature per street line: its shape as a `MultiLineString` (a street
/// is often several pieces of road), its level as [levelProperty].
Map<String, Object> streetLinesGeoJson(Iterable<StreetLine> lines) =>
    _collection([
      for (final line in lines)
        _feature(
          id: line.street.value,
          properties: {levelProperty: line.level.name},
          geometry: _multiLine(line.shape),
        ),
    ]);

/// One `Point` feature per house dot, with its status as [statusProperty]
/// and its number as [numberProperty].
Map<String, Object> houseDotsGeoJson(Iterable<HouseDot> dots) => _collection([
  for (final dot in dots)
    _feature(
      id: dot.street.value,
      properties: {
        statusProperty: dot.status.name,
        numberProperty: dot.number.label,
      },
      geometry: {'type': 'Point', 'coordinates': _position(dot.position)},
    ),
]);

/// The road picked on « Ajouter des rues » (PLAN §5.4), drawn over the
/// others; an empty collection when [shape] has no line (nothing picked).
Map<String, Object> selectedRoadGeoJson(StreetShape shape) => _collection([
  if (!shape.isEmpty)
    _feature(id: 'selected', properties: {}, geometry: _multiLine(shape)),
]);

/// Where the finger tapped on « Ajouter des rues », or where the street
/// found by the search is (PLAN §5.4): one `Point`, marked until the road
/// shows; an empty collection when there is none.
Map<String, Object> selectedPointGeoJson(GeoPoint? point) => _collection([
  if (point != null)
    _feature(
      id: 'selected-point',
      properties: {},
      geometry: {'type': 'Point', 'coordinates': _position(point)},
    ),
]);

/// The roads ticked on « Ajouter des rues » (PLAN §5.14): one
/// `MultiLineString` per ticked street whose road is known, with the
/// street's BAN id as its id, so a tap on it names the street.
Map<String, Object> pickedRoadsGeoJson(Iterable<PickedRoad> picked) =>
    _collection([
      for (final pick in picked)
        if (!pick.road.isEmpty)
          _feature(
            id: pick.street.value,
            properties: {},
            geometry: _multiLine(pick.road),
          ),
    ]);

/// The ✓ discs of the roads ticked: one `Point` per ticked street at its
/// mark, road known or not, with the street's BAN id as its id.
Map<String, Object> pickedMarksGeoJson(Iterable<PickedRoad> picked) =>
    _collection([
      for (final pick in picked)
        _feature(
          id: pick.street.value,
          properties: {},
          geometry: {'type': 'Point', 'coordinates': _position(pick.mark)},
        ),
    ]);

/// The property holding a dot's [PartDot.look] on « Partie de la rue », by
/// name (`kept`, `leftOut`, `otherSide`, `shared`): the style colours the
/// dot from it.
const lookProperty = 'look';

/// The whole road on « Partie de la rue » (PLAN §5.15), drawn grey: one
/// `MultiLineString`; an empty collection when [shape] has no line.
Map<String, Object> partRoadGeoJson(StreetShape shape) => _collection([
  if (!shape.isEmpty)
    _feature(id: 'part-road', properties: {}, geometry: _multiLine(shape)),
]);

/// The house dots of « Partie de la rue »: one `Point` per dot, named by
/// its number, with its look as [lookProperty] and its number as
/// [numberProperty].
Map<String, Object> partDotsGeoJson(Iterable<PartDot> dots) => _collection([
  for (final dot in dots)
    _feature(
      id: dot.number.label,
      properties: {
        lookProperty: dot.look.name,
        numberProperty: dot.number.label,
      },
      geometry: {'type': 'Point', 'coordinates': _position(dot.position)},
    ),
]);

/// The property telling a feature of the other secteurs' stretches on
/// « Partie de la rue » (PLAN §5.15): [OtherStretchPart.name].
const otherPartProperty = 'other';

/// The property holding which side of its line a stretch is drawn: -1 on
/// the left, 1 on the right (MapLibre's `line-offset` counts to the right
/// of the line's direction).
const sideProperty = 'side';

/// The property holding the words of a stretch's label (« Secteur 12 »).
const labelProperty = 'label';

/// The features of another secteur's stretch.
enum OtherStretchPart {
  /// The stretch, a `LineString` drawn hatched beside the road.
  band,

  /// Where its label goes, a `Point`.
  label,
}

/// The other secteurs' stretches of « Partie de la rue »: for each, its
/// line with the side it is drawn ([sideProperty]), and its label point
/// with [labelOf] its secteur number as [labelProperty].
Map<String, Object> partOthersGeoJson(
  Iterable<OtherStretch> others,
  String Function(int sector) labelOf,
) => _collection([
  for (final (index, stretch) in others.indexed) ...[
    _feature(
      id: 'other-$index',
      properties: {
        otherPartProperty: OtherStretchPart.band.name,
        sideProperty: stretch.onLeft ? -1 : 1,
      },
      geometry: {
        'type': 'LineString',
        'coordinates': [for (final point in stretch.line) _position(point)],
      },
    ),
    _feature(
      id: 'other-$index-label',
      properties: {
        otherPartProperty: OtherStretchPart.label.name,
        labelProperty: labelOf(stretch.sector.value),
      },
      geometry: {'type': 'Point', 'coordinates': _position(stretch.labelAt)},
    ),
  ],
]);

/// The property telling which part of the zone a feature draws:
/// [ZonePart.name], so each layer of the zone keeps its own.
const zonePartProperty = 'part';

/// The parts of a zone drawn on « Ajouter des rues » (PLAN §5.14).
enum ZonePart {
  /// The map outside the zone, dimmed: the whole world with the zone as a
  /// hole.
  shade,

  /// The zone's dashed edge.
  edge,

  /// The round handle at its south-east corner, where a drag resizes it.
  handle,
}

/// The zone drawn on « Ajouter des rues » (PLAN §5.14, PickZone mockup):
/// one feature per [ZonePart]; an empty collection when there is none.
Map<String, Object> zoneGeoJson(GeoBounds? zone) {
  if (zone == null) return _collection([]);
  // The zone's corners, round from the south-west, back to the first
  // (GeoJSON closes a ring by repeating its first position).
  final ring = [
    [zone.west, zone.south],
    [zone.east, zone.south],
    [zone.east, zone.north],
    [zone.west, zone.north],
    [zone.west, zone.south],
  ];
  Map<String, Object> part(ZonePart part, Map<String, Object> geometry) =>
      _feature(
        id: 'zone-${part.name}',
        properties: {zonePartProperty: part.name},
        geometry: geometry,
      );
  return _collection([
    part(ZonePart.shade, {
      'type': 'Polygon',
      'coordinates': [_world, ring],
    }),
    part(ZonePart.edge, {'type': 'LineString', 'coordinates': ring}),
    part(ZonePart.handle, {
      'type': 'Point',
      'coordinates': [zone.east, zone.south],
    }),
  ]);
}

/// The whole map as Web Mercator shows it (to 85° north and south), the
/// outer ring of the zone's shade.
const _world = [
  [-180.0, -85.0],
  [180.0, -85.0],
  [180.0, 85.0],
  [-180.0, 85.0],
  [-180.0, -85.0],
];

Map<String, Object> _collection(List<Map<String, Object>> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

Map<String, Object> _feature({
  required String id,
  required Map<String, Object> properties,
  required Map<String, Object> geometry,
}) => {
  'type': 'Feature',
  'id': id,
  'properties': properties,
  'geometry': geometry,
};

Map<String, Object> _multiLine(StreetShape shape) => {
  'type': 'MultiLineString',
  'coordinates': [
    for (final line in shape.lines)
      [for (final point in line) _position(point)],
  ],
};

/// GeoJSON writes a position longitude first, unlike people.
List<double> _position(GeoPoint point) => [point.longitude, point.latitude];
