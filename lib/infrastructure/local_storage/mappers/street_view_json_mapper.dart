// Translation between the street view preferences (PLAN §6.3) and the JSON
// the phone keeps for them. Pure functions: no file here, so they are
// tested alone.
//
// The schema, version 1:
//
//   { version: 1, hideDone: [streetId, …] }   (ids sorted, each once)
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The schema version this code writes and reads.
const storedStreetViewVersion = 1;

/// The stored form of the preferences: the streets whose done houses are
/// hidden ([hidingDone]). Sorted, so the same set always makes the same
/// file.
Map<String, Object?> streetViewToJson(Set<StreetId> hidingDone) => {
  'version': storedStreetViewVersion,
  'hideDone': [for (final id in hidingDone) id.value]..sort(),
};

/// The streets whose done houses are hidden, read from [json] as
/// `jsonDecode` gives it. Throws a [FormatException] when it is not a
/// version 1 file.
Set<StreetId> streetViewFromJson(Object? json) {
  // A map pattern: matches only a map with these two entries of these
  // types, and names the list.
  if (json case {
    'version': storedStreetViewVersion,
    'hideDone': final List<Object?> ids,
  }) {
    return {
      for (final id in ids)
        if (id case final String value when value.trim().isNotEmpty)
          StreetId(value)
        else
          throw FormatException('Not a street id: $id'),
    };
  }
  throw FormatException('Not street view preferences: $json');
}
