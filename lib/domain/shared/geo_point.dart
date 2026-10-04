import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a (latitude, longitude) pair cannot become a [GeoPoint].
enum GeoPointFailure {
  /// The latitude is not a number between -90 and 90.
  latitudeOutOfRange,

  /// The longitude is not a number between -180 and 180.
  longitudeOutOfRange,
}

/// A place on Earth in WGS 84 degrees, the system of the address base (BAN)
/// and of the map: where a house's entrance is.
///
/// Named fields rather than a pair, because services disagree on the order:
/// the BAN (GeoJSON) writes `[longitude, latitude]`, people say latitude
/// first.
final class GeoPoint {
  const GeoPoint._(this.latitude, this.longitude);

  /// Builds the point, or fails with a [GeoPointFailure] when a coordinate
  /// is out of its range (bounds included) or not a number (`NaN`,
  /// infinity).
  static Result<GeoPoint, GeoPointFailure> create({
    required double latitude,
    required double longitude,
  }) {
    // Written as « not inside » rather than « outside » so that NaN, which
    // fails every comparison, is refused too.
    if (!(latitude >= -90 && latitude <= 90)) {
      return const Err(GeoPointFailure.latitudeOutOfRange);
    }
    if (!(longitude >= -180 && longitude <= 180)) {
      return const Err(GeoPointFailure.longitudeOutOfRange);
    }
    return Ok(GeoPoint._(latitude, longitude));
  }

  /// Degrees north of the equator (negative south), -90 to 90.
  final double latitude;

  /// Degrees east of Greenwich (negative west), -180 to 180.
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
