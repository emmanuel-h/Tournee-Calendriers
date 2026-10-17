// Translation of the Géoplateforme geocoder's answers (`/geocodage/reverse`
// and `/geocodage/search`, already decoded from JSON) into the StreetMatch
// values of the AddressDirectory port. A pure function, tested alone on the
// captured fixtures (test/fixtures/geopf/).
//
// Both calls answer the same GeoJSON FeatureCollection, one feature a
// street. As for the BAN lookup: a document of the wrong shape fails the
// whole call (the adapter turns the FormatException into a service error),
// while one unreadable feature is only left out.
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// Reads the `features` of a geocoder answer, in the service's order (the
/// nearest or best first).
///
/// A feature without a non-blank `id` (the BAN `idVoie`), a valid
/// [StreetName], a valid [Commune] (`citycode`, `city`) or a usable point
/// (GeoJSON `[longitude, latitude]`, an altitude after them ignored) is left
/// out.
///
/// Throws a [FormatException] when [json] is not a feature collection (the
/// error document of a refused query, for instance).
List<StreetMatch> streetMatchesFromJson(Object? json) {
  if (json case {'features': final List<Object?> features}) {
    return [for (final feature in features) ?_match(feature)];
  }
  throw const FormatException('Not a geocoding feature collection');
}

/// The street of one feature, or null when it cannot be read.
StreetMatch? _match(Object? feature) {
  if (feature
      case {
        'geometry': {
          'coordinates': [final num longitude, final num latitude, ...],
        },
        'properties': {
          'id': final String id,
          'name': final String name,
          'citycode': final String citycode,
          'city': final String city,
        },
      }
      when id.trim().isNotEmpty) {
    // A record of three results, matched in one step: the street is built
    // only when all three are values.
    return switch ((
      StreetName.create(name),
      Commune.create(inseeCode: citycode, name: city),
      GeoPoint.create(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
    )) {
      (
        Ok(value: final streetName),
        Ok(value: final commune),
        Ok(value: final position),
      ) =>
        StreetMatch(
          id: BanStreetId(id),
          name: streetName,
          commune: commune,
          position: position,
        ),
      _ => null,
    };
  }
  return null;
}
