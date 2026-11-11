// The shared index of the secteurs' parts, `streetParts/{banId}` (PLAN
// §6.2, §5.15 « Other secteurs »): one document per BAN street, holding
// an entry per secteur that holds some of it.
//
//   sector: "<sectorId>"                 ← the secteur of the last write
//   parts: { "<sectorId>": { number: 12, centreName: "CS Villefranche",
//                            odd: side, even: side }, … }
//
// `side` as on a street (street_part_fields.dart), both always written.
// Each secteur writes only its own entry, with a set that merges into the
// document, so two secteurs writing at once never overwrite each other;
// `sector` names that entry for the security rules, which cannot tell
// which key of a map a write changed (PLAN §8.2). Pure functions, tested
// alone.
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/infrastructure/shared/mappers/street_part_fields.dart';

/// The document `openSectors/{uid}`: the secteur the phone has open,
/// which the security rules read to let its account read the index only
/// while it is an active member there (#147, PLAN §8.2).
Map<String, Object?> openSectorDocument(SectorId sector) => {
  'sectorId': sector.value,
};

/// The write saying [sector], numbered [number] of the centre [centre],
/// holds [part] of the street: merged into the document.
Map<String, Object?> heldPartWrite(
  SectorId sector, {
  required SectorNumber number,
  required RescueCentre centre,
  required StreetPart part,
}) => {
  'sector': sector.value,
  'parts': {
    sector.value: {
      'number': number.value,
      'centreName': centre.name,
      ...storedSides(part),
    },
  },
};

/// The write saying [sector] holds none of the street: its entry replaced
/// by [removal], Firestore's « delete this field » (passed in, so this
/// stays free of the Firestore SDK), merged into the document.
Map<String, Object?> releasedPartWrite(SectorId sector, Object removal) => {
  'sector': sector.value,
  'parts': {sector.value: removal},
};

/// What the secteurs other than [except] hold of the street, read from its
/// [document]; none when there is no document. An entry that cannot be
/// read (written by a newer app, or by hand) is left out rather than
/// hiding the others: the index is only a hint.
List<SectorPart> otherPartsFrom(
  Map<String, Object?>? document, {
  required SectorId except,
}) {
  final parts = document?['parts'];
  if (parts is! Map<String, Object?>) return const [];
  return [
    for (final MapEntry(:key, :value) in parts.entries)
      if (key != except.value) ?_entryFrom(value),
  ];
}

/// The entry [json]; null when it is not one.
SectorPart? _entryFrom(Object? json) {
  if (json case {
    'number': final int number,
    'centreName': final String centreName,
  }) {
    final sector = SectorNumber.create(number);
    final centre = RescueCentre.create(centreName);
    if ((sector, centre) case (
      Ok(value: final sector),
      Ok(value: final centre),
    )) {
      try {
        return SectorPart(sector: sector, centre: centre, part: partFrom(json));
      } on FormatException {
        return null;
      }
    }
  }
  return null;
}
