// Translation between the tournées that received the phone's streets
// (« Les ajouter à la tournée », PLAN §5.0, §6.3) and the JSON the phone
// keeps for them. Pure functions: no file here, so they are tested alone.
//
// The schema, version 1:
//
//   { version: 1, movedInto: [tourneeId, …] }   (ids sorted, each once)
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// The schema version this code writes and reads.
const storedMovedStreetsVersion = 1;

/// The stored form of the [tournees] that received the phone's streets.
/// Sorted, so the same set always makes the same file.
Map<String, Object?> movedStreetsToJson(Set<TourneeId> tournees) => {
  'version': storedMovedStreetsVersion,
  'movedInto': [for (final id in tournees) id.value]..sort(),
};

/// The tournées that received the phone's streets, read from [json] as
/// `jsonDecode` gives it. Throws a [FormatException] when it is not a
/// version 1 file.
Set<TourneeId> movedStreetsFromJson(Object? json) {
  if (json case {
    'version': storedMovedStreetsVersion,
    'movedInto': final List<Object?> ids,
  }) {
    return {
      for (final id in ids)
        if (id case final String value when value.trim().isNotEmpty)
          TourneeId(value)
        else
          throw FormatException('Not a tournée id: $id'),
    };
  }
  throw FormatException('Not the tournées the streets went into: $json');
}
