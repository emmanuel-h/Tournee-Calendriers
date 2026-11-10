// Translation of the answers of the two commune searches (already decoded
// from JSON) into the values of the CommuneSearch port: geo.api.gouv.fr's
// `communes`, and the Géoplateforme geocoder asked for municipalities, its
// stand-in when it fails (#137). Pure functions, tested alone on the
// captured fixtures (test/fixtures/geo_api/, test/fixtures/geopf/).
//
// As for the BAN: a document of the wrong shape fails the whole call (the
// adapter turns the FormatException into a service error), while one
// unreadable entry is only left out, so the other suggestions still show.
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

final _postcodeShape = RegExp(r'^\d{5}$');

/// Reads the answer of `/communes?nom=…`: a list of `{nom, code,
/// codesPostaux, centre}`, in the service's order.
///
/// An entry without a valid [Commune] (INSEE `code`, non-blank `nom`) is
/// left out; so is a postcode that is not five digits. A missing
/// `codesPostaux` means none; a missing or unreadable `centre` (a GeoJSON
/// point, `[longitude, latitude]`), no centre.
///
/// Throws a [FormatException] when [json] is not a list.
List<CommuneMatch> communeMatchesFromJson(Object? json) {
  if (json is! List<Object?>) {
    throw const FormatException('Not a list of communes');
  }
  return [for (final entry in json) ?_match(entry)];
}

/// Reads the answer of the geocoder's `/geocodage/search?type=municipality`:
/// a GeoJSON feature collection, one feature a commune, best first.
///
/// Each feature gives `name`, `citycode` (INSEE) and a single `postcode`
/// in its properties, and its centre as a point. As in
/// [communeMatchesFromJson], a feature without a valid [Commune] is left
/// out, a postcode that is not five digits is none, and an unreadable point
/// is no centre.
///
/// Throws a [FormatException] when [json] is not a feature collection (the
/// error document of a refused query, for instance).
List<CommuneMatch> communeMatchesFromGeocoderJson(Object? json) {
  if (json case {'features': final List<Object?> features}) {
    return [for (final feature in features) ?_feature(feature)];
  }
  throw const FormatException('Not a geocoding feature collection');
}

/// The commune of one geocoder feature, or null when it cannot be read.
CommuneMatch? _feature(Object? feature) {
  // `&&` in a pattern: the properties are kept whole (for the postcode) and
  // matched for the two fields a commune needs.
  if (feature case {
    'properties':
        final Map<Object?, Object?> properties &&
        {'name': final String name, 'citycode': final String code},
  }) {
    return switch (Commune.create(inseeCode: code, name: name)) {
      Ok(:final value) => CommuneMatch(
        commune: value,
        postcodes: _postcodes([properties['postcode']]),
        centre: _centre(feature['geometry']),
      ),
      Err() => null,
    };
  }
  return null;
}

/// The commune of one entry, or null when it cannot be read.
CommuneMatch? _match(Object? entry) {
  if (entry case {'nom': final String name, 'code': final String code}) {
    return switch (Commune.create(inseeCode: code, name: name)) {
      Ok(:final value) => CommuneMatch(
        commune: value,
        postcodes: _postcodes(entry['codesPostaux']),
        centre: _centre(entry['centre']),
      ),
      Err() => null,
    };
  }
  return null;
}

/// The point of a GeoJSON `Point` [json]; null when it is not one or out
/// of range.
GeoPoint? _centre(Object? json) {
  if (json case {
    'type': 'Point',
    'coordinates': [final num longitude, final num latitude],
  }) {
    return switch (GeoPoint.create(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    )) {
      Ok(:final value) => value,
      Err() => null,
    };
  }
  return null;
}

/// The five-digit strings of [json] when it is a list; none otherwise.
List<String> _postcodes(Object? json) => [
  if (json is List<Object?>)
    for (final postcode in json)
      if (postcode is String && _postcodeShape.hasMatch(postcode)) postcode,
];
