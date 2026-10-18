// Reads the named lines of one layer of a Mapbox Vector Tile (MVT, version
// 2), the format of the OpenFreeMap tiles: the roads of the
// `transportation_name` layer with their `name`. Pure functions over the
// tile's bytes, tested on tiles the tests build.
//
// A tile is a protobuf message (see protobuf_reader.dart):
//   Tile    { repeated Layer layers = 3; }
//   Layer   { string name = 1; repeated Feature features = 2;
//             repeated string keys = 3; repeated Value values = 4;
//             uint32 extent = 5 [default 4096]; }
//   Feature { repeated uint32 tags = 2 [packed]; GeomType type = 3;
//             repeated uint32 geometry = 4 [packed]; }
//   Value   { string string_value = 1; … numbers and booleans … }
// A feature's tags are pairs of indexes: a key in `keys`, a value in
// `values`. Its geometry is a list of commands on a cursor that starts at
// (0, 0): « move to » starts a line, « line to » extends it, each by a
// zigzag-encoded step (dx, dy). Coordinates run from 0 to `extent` across
// the tile, x to the east, y to the south; a road may reach a little beyond
// (the tile's buffer, which its neighbour shows too).
import 'dart:io' show gzip;

import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/protobuf_reader.dart';

/// A point of a tile, in its own coordinates (0 to the layer's extent).
typedef TilePoint = ({int x, int y});

/// A named road of a tile: one or more lines.
final class TileRoad {
  const TileRoad(this.name, this.lines);

  /// The road's `name`, as OpenStreetMap writes it.
  final String name;

  /// Each line, its points in the order the road runs.
  final List<List<TilePoint>> lines;
}

/// The named lines of one layer of a tile, and the size of the tile in its
/// coordinates.
final class TileLayer {
  const TileLayer({required this.extent, required this.roads});

  /// A tile without the layer: nothing on it.
  static const empty = TileLayer(extent: defaultExtent, roads: []);

  /// The extent a layer has when it does not say.
  static const defaultExtent = 4096;

  /// The tile's width and height in its coordinates.
  final int extent;

  /// Every line of the layer that has a text `name`.
  final List<TileRoad> roads;
}

const _tileLayersField = 3;
const _layerNameField = 1;
const _layerFeaturesField = 2;
const _layerKeysField = 3;
const _layerValuesField = 4;
const _layerExtentField = 5;
const _valueStringField = 1;
const _featureTagsField = 2;
const _featureTypeField = 3;
const _featureGeometryField = 4;

/// The geometry type of a line (`GeomType.LINESTRING`).
const _lineStringType = 2;

const _moveTo = 1;
const _lineTo = 2;
const _closePath = 7;

/// The named lines of the layer [layerName] of the tile [bytes] (gzipped
/// or not: a server may send them as stored). [TileLayer.empty] when the
/// tile has no such layer.
///
/// Features that are not lines, or have no text `name`, are left out.
/// Throws a [FormatException] when the bytes are not a vector tile.
TileLayer namedLinesOf(List<int> bytes, String layerName) {
  final tile = ProtobufReader(_gunzipped(bytes));
  while (!tile.isAtEnd) {
    final key = tile.readKey();
    if (key.field == _tileLayersField &&
        key.wireType == lengthDelimitedWireType) {
      final layer = _readLayer(tile.readMessage(), layerName);
      if (layer != null) return layer;
    } else {
      tile.skip(key.wireType);
    }
  }
  return TileLayer.empty;
}

/// [bytes] uncompressed when they are gzipped: they start with the two
/// bytes 1f 8b. The `http` client uncompresses what the server says is
/// gzipped; this covers a tile stored gzipped and sent as it is.
List<int> _gunzipped(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b
    ? gzip.decode(bytes)
    : bytes;

/// The layer [layer] when it is named [wanted], null otherwise. Its
/// features are read only once the whole layer is: the keys and values
/// they point to may come after them.
TileLayer? _readLayer(ProtobufReader layer, String wanted) {
  String? name;
  var extent = TileLayer.defaultExtent;
  final features = <ProtobufReader>[];
  final keys = <String>[];
  final values = <String?>[];
  while (!layer.isAtEnd) {
    final key = layer.readKey();
    switch (key.field) {
      case _layerNameField:
        name = layer.readString();
      case _layerFeaturesField:
        features.add(layer.readMessage());
      case _layerKeysField:
        keys.add(layer.readString());
      case _layerValuesField:
        values.add(_readStringValue(layer.readMessage()));
      case _layerExtentField:
        extent = layer.readVarint();
      default:
        layer.skip(key.wireType);
    }
  }
  if (name != wanted) return null;
  // The key `name` once, rather than a text comparison per feature.
  final nameKey = keys.indexOf('name');
  return TileLayer(
    extent: extent,
    roads: [
      for (final feature in features) ?_readRoad(feature, nameKey, values),
    ],
  );
}

/// The text of a `Value`, null when it holds a number or a boolean.
String? _readStringValue(ProtobufReader value) {
  String? text;
  while (!value.isAtEnd) {
    final key = value.readKey();
    if (key.field == _valueStringField) {
      text = value.readString();
    } else {
      value.skip(key.wireType);
    }
  }
  return text;
}

/// The feature as a road when it is a line with a text `name` (the key at
/// [nameKey] of the layer), null otherwise.
TileRoad? _readRoad(ProtobufReader feature, int nameKey, List<String?> values) {
  final tags = <int>[];
  final geometry = <int>[];
  int? type;
  while (!feature.isAtEnd) {
    final key = feature.readKey();
    switch (key.field) {
      case _featureTagsField:
        feature.readVarints(key.wireType, tags);
      case _featureTypeField:
        type = feature.readVarint();
      case _featureGeometryField:
        feature.readVarints(key.wireType, geometry);
      default:
        feature.skip(key.wireType);
    }
  }
  if (type != _lineStringType || nameKey < 0) return null;
  String? name;
  for (var i = 0; i + 1 < tags.length; i += 2) {
    if (tags[i] != nameKey) continue;
    final value = tags[i + 1];
    if (value >= values.length) {
      throw const FormatException('Tag pointing past the values');
    }
    name = values[value];
  }
  if (name == null) return null;
  return TileRoad(name, _lines(geometry));
}

/// The lines drawn by the geometry commands of a line feature.
List<List<TilePoint>> _lines(List<int> commands) {
  final lines = <List<TilePoint>>[];
  var x = 0;
  var y = 0;
  var i = 0;
  while (i < commands.length) {
    // A command: its id in the 3 low bits, how many times in the others.
    final command = commands[i] & 0x7;
    final count = commands[i] >> 3;
    i++;
    if (command == _closePath) continue;
    if (command != _moveTo && command != _lineTo) {
      throw FormatException('Unknown geometry command $command');
    }
    if (i + 2 * count > commands.length) {
      throw const FormatException('Geometry cut short');
    }
    for (var step = 0; step < count; step++) {
      x += zigzagDecode(commands[i++]);
      y += zigzagDecode(commands[i++]);
      if (command == _moveTo) {
        lines.add([(x: x, y: y)]);
      } else if (lines.isEmpty) {
        throw const FormatException('Line drawn before any move');
      } else {
        lines.last.add((x: x, y: y));
      }
    }
  }
  return lines;
}
