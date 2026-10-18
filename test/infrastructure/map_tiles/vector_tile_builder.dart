// Builds small vector tiles for the tests, byte by byte, so the reader is
// tested on tiles whose every byte the test chose (no real tile, no real
// place). The format is described in lib/infrastructure/map_tiles/mappers/
// vector_tile.dart.
import 'dart:convert';

/// Writes protobuf fields.
final class ProtobufWriter {
  final bytes = <int>[];

  /// A varint of a number ≥ 0.
  void varint(int value) {
    var rest = value;
    while (rest >= 0x80) {
      bytes.add((rest & 0x7f) | 0x80);
      rest >>= 7;
    }
    bytes.add(rest);
  }

  void key(int field, int wireType) => varint(field << 3 | wireType);

  void varintField(int field, int value) {
    key(field, 0);
    varint(value);
  }

  void bytesField(int field, List<int> content) {
    key(field, 2);
    varint(content.length);
    bytes.addAll(content);
  }

  void stringField(int field, String text) =>
      bytesField(field, utf8.encode(text));

  /// [values] as one packed field.
  void packedField(int field, List<int> values) {
    final packed = ProtobufWriter();
    values.forEach(packed.varint);
    bytesField(field, packed.bytes);
  }
}

/// The zigzag code of [value] (see `zigzagDecode`).
int zigzag(int value) => value >= 0 ? value * 2 : -value * 2 - 1;

/// The geometry commands drawing [lines]: a « move to » to the first point
/// of each line, then one « line to » with the steps to the others.
List<int> lineCommands(List<List<(int, int)>> lines) {
  final commands = <int>[];
  var (x, y) = (0, 0);
  for (final line in lines) {
    for (var i = 0; i < line.length; i++) {
      if (i == 0) commands.add(1 | 1 << 3);
      if (i == 1) commands.add(2 | (line.length - 1) << 3);
      final (px, py) = line[i];
      commands
        ..add(zigzag(px - x))
        ..add(zigzag(py - y));
      (x, y) = (px, py);
    }
  }
  return commands;
}

/// A feature of a test layer: the index of its `name` value (or none), its
/// geometry type and its commands.
final class TestFeature {
  const TestFeature({
    required this.tags,
    this.type = 2,
    required this.geometry,
    this.packed = true,
  });

  /// A line named with the value at [nameValue], drawing [lines].
  factory TestFeature.road(int nameValue, List<List<(int, int)>> lines) =>
      TestFeature(tags: [0, nameValue], geometry: lineCommands(lines));

  final List<int> tags;
  final int type;
  final List<int> geometry;

  /// Whether tags and geometry are packed (the usual way) or written one
  /// field per number.
  final bool packed;

  List<int> encode() {
    final writer = ProtobufWriter()
      // A feature id, which the reader skips.
      ..varintField(1, 7);
    if (packed) {
      writer.packedField(2, tags);
    } else {
      for (final tag in tags) {
        writer.varintField(2, tag);
      }
    }
    writer.varintField(3, type);
    if (packed) {
      writer.packedField(4, geometry);
    } else {
      for (final command in geometry) {
        writer.varintField(4, command);
      }
    }
    return writer.bytes;
  }
}

/// A layer of a test tile. Its keys are [keys] (`name` first by default);
/// its values the texts of [names], then [numbers] as integer values.
List<int> layer(
  String name, {
  List<TestFeature> features = const [],
  List<String> keys = const ['name'],
  List<String> names = const [],
  List<int> numbers = const [],
  int? extent,
  bool featuresFirst = true,
}) {
  final writer = ProtobufWriter()
    // The version, which the reader skips.
    ..varintField(15, 2)
    ..stringField(1, name);
  void writeFeatures() {
    for (final feature in features) {
      writer.bytesField(2, feature.encode());
    }
  }

  if (featuresFirst) writeFeatures();
  for (final key in keys) {
    writer.stringField(3, key);
  }
  for (final text in names) {
    writer.bytesField(4, (ProtobufWriter()..stringField(1, text)).bytes);
  }
  for (final number in numbers) {
    writer.bytesField(4, (ProtobufWriter()..varintField(4, number)).bytes);
  }
  if (extent != null) writer.varintField(5, extent);
  if (!featuresFirst) writeFeatures();
  return writer.bytes;
}

/// A tile holding [layers].
List<int> tile(List<List<int>> layers) {
  final writer = ProtobufWriter();
  for (final layer in layers) {
    writer.bytesField(3, layer);
  }
  return writer.bytes;
}
