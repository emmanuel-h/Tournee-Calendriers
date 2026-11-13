import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/road_side.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// What an answer of the BD TOPO road stretches holds (PLAN §5.18).
final class BdTopoRoads {
  /// [roads] is copied, so changing the list given here afterwards does
  /// not change this value.
  BdTopoRoads({required this.matched, required List<BanRoad> roads})
    : roads = List.unmodifiable(roads);

  /// How many stretches the area asked holds: more than [roads] when the
  /// service gave only its first ones (`numberMatched`).
  final int matched;

  /// The stretches read, a road per side when the two sides differ, in
  /// the order the service gave them. Read-only.
  final List<BanRoad> roads;
}

/// Reads a GeoJSON answer of the Géoplateforme WFS for
/// `BDTOPO_V3:troncon_de_route` (fixtures in `test/fixtures/bdtopo/`).
///
/// Each stretch gives, for each side (`_gauche` and `_droite`, walking the
/// line the way it runs), the BAN id of the street, its BAN name, the
/// collaborative name of the road and the INSEE code of the commune:
/// - the same street on both sides: one [BanRoad], on both sides;
/// - two streets: a [BanRoad] per side;
/// - a BAN street on one side only: that side alone, the other is a
///   verge, not a street to visit;
/// - no BAN street at all: one [BanRoad] without id, by the road's own
///   name (left side first), when it has one; left out otherwise.
///
/// A stretch the app cannot read (not a line, a point off the Earth) is
/// left out rather than failing the whole answer. Throws a
/// [FormatException] when [json] is not a collection of stretches.
BdTopoRoads banRoadsFromJson(Object? json) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('BD TOPO: the answer is not an object');
  }
  final features = json['features'];
  if (features is! List<Object?>) {
    throw const FormatException('BD TOPO: the answer has no stretches');
  }
  final roads = [for (final feature in features) ..._roadsOf(feature)];
  return BdTopoRoads(
    matched: switch (json['numberMatched']) {
      final int matched => matched,
      // GeoServer may say « unknown »: what was given is all there is to
      // count.
      _ => features.length,
    },
    roads: roads,
  );
}

/// The [BanRoad]s of one stretch: none when it cannot be read.
List<BanRoad> _roadsOf(Object? feature) {
  if (feature is! Map<String, Object?>) return const [];
  final properties = feature['properties'];
  if (properties is! Map<String, Object?>) return const [];
  final shape = _shapeOf(feature['geometry']);
  if (shape == null || shape.isEmpty) return const [];

  final left = _Side.of(properties, 'gauche');
  final right = _Side.of(properties, 'droite');
  if (left.id == null && right.id == null) {
    final name = left.ownName ?? right.ownName;
    if (name == null) return const [];
    return [
      BanRoad(
        banId: null,
        name: name,
        commune: left.commune ?? right.commune,
        shape: shape,
      ),
    ];
  }
  if (left.sameStreetAs(right)) return [left.road(shape, side: null)];
  return [
    if (left.id != null) left.road(shape, side: RoadSide.left),
    if (right.id != null) right.road(shape, side: RoadSide.right),
  ];
}

/// What one side of a stretch says.
final class _Side {
  const _Side(this.id, this.banName, this.ownName, this.commune);

  factory _Side.of(Map<String, Object?> properties, String side) => _Side(
    switch (_text(properties['identifiant_voie_ban_$side'])) {
      final id? => BanStreetId(id),
      null => null,
    },
    _text(properties['nom_voie_ban_$side']),
    _text(properties['nom_collaboratif_$side']),
    switch (_text(properties['insee_commune_$side'])) {
      final code? => switch (InseeCode.parse(code)) {
        Ok(:final value) => value,
        Err() => null,
      },
      null => null,
    },
  );

  final BanStreetId? id;

  /// The street's name in the BAN (« Rue Nationale »).
  final String? banName;

  /// The road's own name, in capitals and abbreviated (« R NATIONALE »).
  final String? ownName;

  final InseeCode? commune;

  BanRoad road(StreetShape shape, {required RoadSide? side}) => BanRoad(
    banId: id,
    // The BAN's name when it gives one; a street without any name keeps an
    // empty one rather than losing its id.
    name: banName ?? ownName ?? '',
    commune: commune,
    shape: shape,
    side: side,
  );

  /// Whether the same street lies on this side and [other]: then the
  /// stretch is one road, not two.
  bool sameStreetAs(_Side other) =>
      other.id == id && other.banName == banName && other.commune == commune;
}

/// [value] when it is a text with something else than spaces in it.
String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

/// The lines of a GeoJSON `LineString` or `MultiLineString`, null when
/// [geometry] is neither or holds a point the app cannot read.
StreetShape? _shapeOf(Object? geometry) {
  if (geometry is! Map<String, Object?>) return null;
  final coordinates = geometry['coordinates'];
  if (coordinates is! List<Object?>) return null;
  final List<Object?> lines = switch (geometry['type']) {
    'LineString' => [coordinates],
    'MultiLineString' => coordinates,
    _ => const [],
  };
  if (lines.isEmpty) return null;
  final read = <List<GeoPoint>>[];
  for (final line in lines) {
    if (line is! List<Object?>) return null;
    final points = <GeoPoint>[];
    for (final position in line) {
      final point = _pointOf(position);
      if (point == null) return null;
      points.add(point);
    }
    read.add(points);
  }
  return StreetShape(read);
}

/// A GeoJSON position, `[longitude, latitude]` with maybe an altitude
/// after them (ignored); null when it is not one.
GeoPoint? _pointOf(Object? position) {
  if (position is! List<Object?> || position.length < 2) return null;
  final [longitude, latitude, ...] = position;
  if (longitude is! num || latitude is! num) return null;
  return switch (GeoPoint.create(
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
  )) {
    Ok(:final value) => value,
    Err() => null,
  };
}
