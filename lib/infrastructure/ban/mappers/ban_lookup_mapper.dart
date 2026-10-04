// Translation of the BAN `lookup` documents (already decoded from JSON) into
// the values of the AddressDirectory port. Pure functions: no HTTP here, so
// they are tested alone on the captured fixtures (test/fixtures/ban/).
//
// Two kinds of bad data, two answers:
// - the document itself has the wrong shape (no commune, no list): the
//   service answered something else than expected, so the whole call fails
//   with a FormatException, which the adapter turns into a service error;
// - one entry of a list is unusable: real data must never break an import,
//   so the entry is left out and counted, and the rest is kept.
//
// The JSON is read with Dart 3 patterns: `if (json case {'key': final String
// value})` checks that `json` is a map holding a String under 'key' and binds
// it in one step, so no unchecked cast (and no `dynamic` call) is needed.
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// Reads the answer of `/lookup/{inseeCode}`: the commune and its `voies`.
///
/// Every entry of `voies` is kept whatever its `type` (`voie` or
/// `lieu-dit`: a lieu-dit can hold numbers too), in the BAN's order. An entry
/// without a non-blank `idVoie`, a valid [StreetName] or a whole
/// `nbNumeros` ≥ 0 is skipped and counted in
/// [CommuneStreets.skippedStreets].
///
/// Throws a [FormatException] when [json] is not a commune document.
CommuneStreets communeStreetsFromJson(Object? json) {
  if (json case {
    'codeCommune': final String code,
    'nomCommune': final String name,
    'voies': final List<Object?> entries,
  }) {
    final commune = _commune(code, name);
    // `?expr` inside a list literal adds the element only when it is not
    // null: the unreadable entries simply drop out.
    final streets = [for (final entry in entries) ?_directoryStreet(entry)];
    return CommuneStreets(
      commune: commune,
      streets: streets,
      skippedStreets: entries.length - streets.length,
    );
  }
  throw const FormatException('Not a BAN commune document');
}

/// Reads the answer of `/lookup/{idVoie}`: the street, its commune and its
/// `numeros`, in the BAN's order.
///
/// - An entry whose `numero` / `suffixe` do not make a valid [HouseNumber]
///   is skipped and counted in [StreetNumbers.invalidNumbers].
/// - An entry whose number was already read (the BAN sometimes lists a
///   number twice with two positions; `a` and `A` are the same suffix) is
///   skipped and counted in [StreetNumbers.duplicateNumbers]: the first one
///   wins.
/// - An entry without a usable position (missing, null, malformed, out of
///   range) keeps its number, without a position.
///
/// Throws a [FormatException] when [json] is not a street document.
StreetNumbers streetNumbersFromJson(Object? json) {
  if (json
      case {
        'idVoie': final String id,
        'nomVoie': final String name,
        'commune': {'code': final String communeCode, 'nom': final String nom},
        'numeros': final List<Object?> entries,
      }
      when id.trim().isNotEmpty) {
    final streetName = switch (StreetName.create(name)) {
      Ok(:final value) => value,
      Err() => throw FormatException('Unreadable street name', name),
    };
    final commune = _commune(communeCode, nom);

    final numbers = <DirectoryNumber>[];
    final seen = <HouseNumber>{};
    var invalid = 0;
    var duplicates = 0;
    for (final entry in entries) {
      final number = _houseNumber(entry);
      if (number == null) {
        invalid++;
      } else if (!seen.add(number)) {
        // `Set.add` returns false when the set already held the value.
        duplicates++;
      } else {
        numbers.add(
          DirectoryNumber(number: number, position: _position(entry)),
        );
      }
    }
    return StreetNumbers(
      id: BanStreetId(id),
      name: streetName,
      commune: commune,
      numbers: numbers,
      invalidNumbers: invalid,
      duplicateNumbers: duplicates,
    );
  }
  throw const FormatException('Not a BAN street document');
}

Commune _commune(String code, String name) =>
    switch (Commune.create(inseeCode: code, name: name)) {
      Ok(:final value) => value,
      Err() => throw FormatException('Unreadable commune', '$code $name'),
    };

/// The street of one `voies` entry, or null when it cannot be read.
DirectoryStreet? _directoryStreet(Object? entry) {
  if (entry
      case {
        'idVoie': final String id,
        'nomVoie': final String name,
        'nbNumeros': final int count,
      }
      when id.trim().isNotEmpty && count >= 0) {
    return switch (StreetName.create(name)) {
      Ok(:final value) => DirectoryStreet(
        id: BanStreetId(id),
        name: value,
        numberCount: count,
      ),
      Err() => null,
    };
  }
  return null;
}

/// The number of one `numeros` entry, or null when it is not a valid
/// [HouseNumber]. A missing `suffixe` means none, like `null`.
HouseNumber? _houseNumber(Object? entry) {
  // jsonDecode gives a `Map<String, dynamic>`, which is a
  // `Map<String, Object?>`: after this check, reading a key gives an
  // `Object?` that must be checked before use.
  if (entry is! Map<String, Object?>) return null;
  final number = entry['numero'];
  final suffix = entry['suffixe'];
  if (number is! int || (suffix != null && suffix is! String)) return null;
  return switch (HouseNumber.create(number, suffix: suffix as String?)) {
    Ok(:final value) => value,
    Err() => null,
  };
}

/// The position of a `numeros` entry, a GeoJSON point whose coordinates are
/// `[longitude, latitude]` (an altitude after them is ignored), or null.
GeoPoint? _position(Object? entry) {
  if (entry case {
    'position': {'coordinates': [final num longitude, final num latitude, ...]},
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
