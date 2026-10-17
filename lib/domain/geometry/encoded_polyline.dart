import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a text cannot be read as an encoded polyline.
enum EncodedPolylineFailure {
  /// The text does not follow the format: a character outside it, a value
  /// cut short or too long, a latitude without its longitude.
  malformed,

  /// A point decoded is not on Earth (see `GeoPoint.create`).
  outOfRange,
}

/// Coordinates are kept to 0.00001°, about a metre.
const _precision = 1e5;

/// The smallest character of the format (`?`); each 5-bit chunk is written
/// as this plus the chunk.
const _offset = 63;

/// Set on a chunk when another chunk of the same value follows.
const _more = 0x20;

/// The five bits of data in a chunk.
const _chunkBits = 0x1f;

/// No value of a coordinate needs more than six chunks: the largest step,
/// 360° of longitude, is 72 000 000 once doubled, under 2³⁰.
const _maxChunks = 6;

/// [points] written as an *encoded polyline* (Google's format, precision
/// 5): a short ASCII text, about 4 characters a point, instead of two
/// numbers of 15 digits each. A street's shape is stored this way, one
/// text per line (PLAN §6.2).
///
/// Each point is written as its step from the previous one, so the small
/// steps along a street take few characters. Coordinates are rounded to
/// the nearest 0.00001°.
String encodePolyline(Iterable<GeoPoint> points) {
  final text = StringBuffer();
  var previousLatitude = 0;
  var previousLongitude = 0;
  for (final point in points) {
    final latitude = (point.latitude * _precision).round();
    final longitude = (point.longitude * _precision).round();
    _writeValue(latitude - previousLatitude, text);
    _writeValue(longitude - previousLongitude, text);
    previousLatitude = latitude;
    previousLongitude = longitude;
  }
  return text.toString();
}

/// Writes one signed whole number: doubled with its sign in the lowest bit
/// (so small negative numbers stay small), then cut into 5-bit chunks,
/// lowest first, each made a printable character.
void _writeValue(int value, StringBuffer text) {
  // `~` flips every bit: for a negative value it gives a positive number.
  var rest = value < 0 ? ~(value << 1) : value << 1;
  while (rest >= _more) {
    text.writeCharCode((_more | (rest & _chunkBits)) + _offset);
    // `>>=` shifts the bits right: drops the five just written.
    rest >>= 5;
  }
  text.writeCharCode(rest + _offset);
}

/// The points written in [encoded] by [encodePolyline], in a list that
/// cannot be modified; fails with an [EncodedPolylineFailure] when the
/// text is not an encoded polyline or a point is not on Earth.
Result<List<GeoPoint>, EncodedPolylineFailure> decodePolyline(String encoded) {
  final values = <int>[];
  var index = 0;
  while (index < encoded.length) {
    var value = 0;
    var chunks = 0;
    int chunk;
    do {
      if (index == encoded.length || chunks == _maxChunks) {
        return const Err(EncodedPolylineFailure.malformed);
      }
      chunk = encoded.codeUnitAt(index) - _offset;
      if (chunk < 0 || chunk > (_more | _chunkBits)) {
        return const Err(EncodedPolylineFailure.malformed);
      }
      value |= (chunk & _chunkBits) << (5 * chunks);
      index++;
      chunks++;
    } while (chunk >= _more);
    // Undoes the doubling: the lowest bit tells the sign.
    values.add(value.isOdd ? ~(value >> 1) : value >> 1);
  }
  if (values.length.isOdd) return const Err(EncodedPolylineFailure.malformed);

  final points = <GeoPoint>[];
  var latitude = 0;
  var longitude = 0;
  for (var i = 0; i < values.length; i += 2) {
    latitude += values[i];
    longitude += values[i + 1];
    switch (GeoPoint.create(
      latitude: latitude / _precision,
      longitude: longitude / _precision,
    )) {
      case Ok(:final value):
        points.add(value);
      case Err():
        return const Err(EncodedPolylineFailure.outOfRange);
    }
  }
  return Ok(List.unmodifiable(points));
}
