// Translation between a Street and its Firestore document,
// `tournees/{id}/campaigns/{year}/streets/{streetId}` (PLAN §6.2). Pure
// functions: no database here, so they are tested alone.
//
// The document:
//
//   { name, communeName, communeCode, banId | null,
//     deletedAt: time | null, deletedBy: uid | null,      ← street in the Corbeille
//     houses: { "<label>": house } }                       ← "12", "3bis", "3A"
//   house    = { n: 3, sfx: "bis" | null, lat | null, lon | null,
//                status, comeBack: hint | null, by: uid | null, at: time | null,
//                deletedAt: time | null, deletedBy: uid | null,   ← number in the Corbeille
//                and on a building only: labelStyle, layout, dwellings }
//   layout   = [ { esc: "A", floor: 5 | null, doors: ["51", "52"] } ]
//   dwellings = { "A5-51": { status, comeBack, by, at } }
//   status   = "TO_DO" | "DONE" | "NOBODY_HOME" | "COME_BACK"
//   labelStyle = "FLOOR_AND_NUMBER" | "FLOOR_AND_LETTER" | "FREE"
//   time     = a Firestore Timestamp
//
// Why a `layout` next to the `dwellings` map: Firestore gives a map's keys
// in its own order, while the doors of a floor have theirs (« Gauche »
// before « Droite », `110` after `19`), and a floor whose doors were all
// removed has no door to say it exists. The layout lists the staircases in
// order, each floor top first, each door left to right; the dwellings map
// holds the marks, one entry per door, so a mark is a write of
// `houses.8.dwellings.A5-51.status` that never touches another door.
//
// Reading goes back through the domain's own checks (Street.create,
// Building.create, ComeBack.create…), so stored data can never build a
// street that breaks an invariant, and anything they refuse makes the
// street unreadable (a FormatException). Two leftovers of writes that
// crossed a teammate's are skipped instead, since they are normal:
// - a house entry without `n`: a mark that landed just after the house was
//   renumbered (its key deleted) recreates the key with the mark's fields
//   only;
// - a door entry the layout does not list: a mark on a door a teammate's
//   new layout dropped at the same moment.
// `show`: cloud_firestore has a `GeoPoint` of its own, not the domain's.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/stored_values.dart';

/// The document of [street], for a `set` when the street is new.
Map<String, Object?> streetToDocument(Street street) => {
  'name': street.name.text,
  'communeName': street.commune.name,
  'communeCode': street.commune.inseeCode.value,
  'banId': street.banId?.value,
  ...stampFields(street.deletion, by: 'deletedBy', at: 'deletedAt'),
  'houses': {
    for (final house in street.houses) house.number.label: houseEntry(house),
    for (final removed in street.removedHouses)
      removed.number.label: houseEntry(removed.house, removal: removed.removal),
  },
};

/// The entry of [house] in the `houses` map; with [removal] when the number
/// is in the Corbeille.
Map<String, Object?> houseEntry(House house, {ChangeStamp? removal}) => {
  'n': house.number.number,
  'sfx': house.number.suffix,
  'lat': house.position?.latitude,
  'lon': house.position?.longitude,
  'status': statusName(house.status),
  'comeBack': house.comeBack?.hint,
  ...stampFields(house.lastChange, by: 'by', at: 'at'),
  ...stampFields(removal, by: 'deletedBy', at: 'deletedAt'),
  if (house.building case final building?) ...buildingFields(building),
};

/// The fields a building adds to its house entry: `labelStyle`, `layout`
/// and `dwellings`.
Map<String, Object?> buildingFields(Building building) => {
  'labelStyle': labelStyleName(building.style),
  'layout': layoutOf(building),
  'dwellings': {
    for (final (key, dwelling) in doorsOf(building))
      key.id: dwellingEntry(dwelling),
  },
};

/// The `layout` of [building]: one entry per floor, staircases in order,
/// floors top first, door labels left to right.
List<Map<String, Object?>> layoutOf(Building building) => [
  for (final staircase in building.staircases)
    for (final floor in staircase.floors)
      {
        'esc': staircase.name.letter,
        'floor': floor.level,
        'doors': [for (final dwelling in floor.dwellings) dwelling.label.text],
      },
];

/// Every door of [building] with its key, in layout order.
Iterable<(DwellingKey, Dwelling)> doorsOf(Building building) => [
  for (final staircase in building.staircases)
    for (final floor in staircase.floors)
      for (final dwelling in floor.dwellings)
        (DwellingKey(staircase.name, floor.level, dwelling.label), dwelling),
];

/// The entry of a door in the `dwellings` map: its marks only, the layout
/// says where it is.
Map<String, Object?> dwellingEntry(Dwelling dwelling) => {
  'status': statusName(dwelling.status),
  'comeBack': dwelling.comeBack?.hint,
  ...stampFields(dwelling.lastChange, by: 'by', at: 'at'),
};

/// The fields [by] and [at] of [stamp]; both null without one.
Map<String, Object?> stampFields(
  ChangeStamp? stamp, {
  required String by,
  required String at,
}) => {
  by: stamp?.by.value,
  at: switch (stamp) {
    null => null,
    final ChangeStamp stamp => Timestamp.fromDate(stamp.at),
  },
};

/// The stored name of [status]. Fixed names rather than the Dart enum
/// names, so renaming an enum value in the code cannot make the stored
/// streets unreadable; the security rules list the same four.
String statusName(VisitStatus status) => switch (status) {
  VisitStatus.toDo => 'TO_DO',
  VisitStatus.done => 'DONE',
  VisitStatus.nobodyHome => 'NOBODY_HOME',
  VisitStatus.comeBack => 'COME_BACK',
};

/// The stored name of [style].
String labelStyleName(DoorLabelStyle style) => switch (style) {
  DoorLabelStyle.floorAndNumber => 'FLOOR_AND_NUMBER',
  DoorLabelStyle.floorAndLetter => 'FLOOR_AND_LETTER',
  DoorLabelStyle.free => 'FREE',
};

/// The street stored in the document [id] as [data].
///
/// Throws a [FormatException] when [data] is not a street document or
/// holds a value the domain refuses.
Street streetFromDocument(String id, Map<String, Object?> data) {
  if (data case {
    'name': final String name,
    'communeName': final String communeName,
    'communeCode': final String communeCode,
    'banId': final String? banId,
    'deletedAt': final Object? deletedAt,
    'deletedBy': final String? deletedBy,
    'houses': final Map<String, Object?> houses,
  }) {
    final shown = <House>[];
    final removed = <RemovedHouse>[];
    for (final MapEntry(:key, :value) in houses.entries) {
      // A leftover without its number (see the top of this file).
      if (value is Map<String, Object?> && !value.containsKey('n')) continue;
      final (house, removal) = _houseFrom(key, value);
      if (removal == null) {
        shown.add(house);
      } else {
        removed.add(RemovedHouse(house: house, removal: removal));
      }
    }
    return valid(
      Street.create(
        id: identifier(id, StreetId.new),
        name: name,
        commune: valid(
          Commune.create(inseeCode: communeCode, name: communeName),
          'commune',
        ),
        banId: banId == null ? null : identifier(banId, BanStreetId.new),
        houses: shown,
        removedHouses: removed,
        deletion: stampOrNull(deletedBy, deletedAt),
      ),
      'street',
    );
  }
  throw const FormatException('Not a street document');
}

/// The house stored under [key], and its removal when it is in the
/// Corbeille.
(House, ChangeStamp?) _houseFrom(String key, Object? json) {
  if (json
      case final Map<String, Object?> entry &&
          {
            'n': final int n,
            'sfx': final String? sfx,
            'lat': final num? latitude,
            'lon': final num? longitude,
            'status': final String status,
            'comeBack': final String? comeBack,
            'by': final String? by,
            'at': final Object? at,
            'deletedAt': final Object? deletedAt,
            'deletedBy': final String? deletedBy,
          }) {
    final number = valid(HouseNumber.create(n, suffix: sfx), 'house number');
    // The key is the label: a house stored under another key would be a
    // second entry for the same number.
    if (number.label != key) {
      throw FormatException('House stored under another key', key);
    }
    final house = House(
      number: number,
      // On a building the House factory makes it to do, keeping the
      // come-back as the building's own.
      status: _statusFrom(status),
      comeBack: _comeBackOrNull(comeBack),
      lastChange: stampOrNull(by, at),
      building: entry.containsKey('layout') ? _buildingFrom(entry) : null,
      position: _positionOrNull(latitude, longitude),
    );
    return (house, stampOrNull(deletedBy, deletedAt));
  }
  throw FormatException('Not a stored house', key);
}

GeoPoint? _positionOrNull(num? latitude, num? longitude) {
  if (latitude == null && longitude == null) return null;
  if (latitude == null || longitude == null) {
    throw const FormatException('Half a position');
  }
  return valid(
    GeoPoint.create(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    ),
    'position',
  );
}

Building _buildingFrom(Map<String, Object?> json) {
  if (json case {
    'labelStyle': final String style,
    'layout': final List<Object?> layout,
    'dwellings': final Map<String, Object?> dwellings,
  }) {
    // The floors of each staircase in layout order; a `Map` literal keeps
    // the order its keys were added in.
    final floors = <StaircaseName, List<Floor>>{};
    for (final entry in layout) {
      final (staircase, floor) = _floorFrom(entry, dwellings);
      floors.putIfAbsent(staircase, () => []).add(floor);
    }
    return valid(
      Building.create(
        style: _labelStyleFrom(style),
        staircases: [
          for (final MapEntry(:key, :value) in floors.entries)
            Staircase(name: key, floors: value),
        ],
      ),
      'building',
    );
  }
  throw const FormatException('Not a stored building');
}

(StaircaseName, Floor) _floorFrom(
  Object? json,
  Map<String, Object?> dwellings,
) {
  if (json case {
    'esc': final String letter,
    'floor': final int? level,
    'doors': final List<Object?> doors,
  }) {
    final staircase = identifier(letter, StaircaseName.new);
    return (
      staircase,
      Floor(
        level: level,
        dwellings: [
          for (final door in doors)
            _dwellingFrom(staircase, level, door, dwellings),
        ],
      ),
    );
  }
  throw const FormatException('Not a stored floor');
}

Dwelling _dwellingFrom(
  StaircaseName staircase,
  int? level,
  Object? text,
  Map<String, Object?> dwellings,
) {
  final label = valid(
    DwellingLabel.parse(text is String ? text : ''),
    'door label',
  );
  final key = DwellingKey(staircase, level, label);
  if (dwellings[key.id] case {
    'status': final String status,
    'comeBack': final String? comeBack,
    'by': final String? by,
    'at': final Object? at,
  }) {
    return Dwelling(
      label: label,
      status: _statusFrom(status),
      comeBack: _comeBackOrNull(comeBack),
      lastChange: stampOrNull(by, at),
    );
  }
  throw FormatException('Not a stored door', key.id);
}

ComeBack? _comeBackOrNull(String? hint) =>
    hint == null ? null : valid(ComeBack.create(hint), '« repasser » hint');

VisitStatus _statusFrom(String text) => switch (text) {
  'TO_DO' => VisitStatus.toDo,
  'DONE' => VisitStatus.done,
  'NOBODY_HOME' => VisitStatus.nobodyHome,
  'COME_BACK' => VisitStatus.comeBack,
  _ => throw FormatException('Not a stored status', text),
};

DoorLabelStyle _labelStyleFrom(String text) => switch (text) {
  'FLOOR_AND_NUMBER' => DoorLabelStyle.floorAndNumber,
  'FLOOR_AND_LETTER' => DoorLabelStyle.floorAndLetter,
  'FREE' => DoorLabelStyle.free,
  _ => throw FormatException('Not a stored label style', text),
};
