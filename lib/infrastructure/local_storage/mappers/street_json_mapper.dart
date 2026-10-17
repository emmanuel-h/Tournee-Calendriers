// Translation between a Street and the JSON the phone storage keeps for it
// (the streets used while no tournée is open). Pure functions: no file
// here, so they are tested alone.
//
// The schema, version 3 (PLAN §6.3):
//
//   { version: 3, id, name, commune: { inseeCode, name }, banId | null,
//     deletion: stamp | null, shape: ["<encoded polyline>", …],
//     assignees: [memberId, …], houses: [house], removedHouses: [{ house,
//     removal: stamp }] }
//   house    = { number: "3bis", status, comeBack: when | null,
//                lastChange: stamp | null, tries: 1–99,   ← only from the first try
//                position: { latitude, longitude } | null,
//                building: building | null }
//   building = { style, staircases: [{ name: "A", floors: [{ level | null,
//                dwellings: [{ label, status, comeBack,
//                              lastChange, tries }] }] }] }
//   stamp    = { by: memberId, at: "2026-11-02T14:02:00.000Z" }  (UTC)
//   status   = "toDo" | "done" | "nobodyHome" | "comeBack"
//   when     = "" | "2026-10-24" | "2026-10-24T18"   ← see come_back_text.dart
//
// A house or door « comeBack » has its time in `comeBack` ("" for none); any
// other status has `comeBack: null`. A building keeps its own « repasser »
// there, its status being always "toDo".
//
// Version 1 (T1.6 to T1.12) had no "comeBack" status: « repasser » was a
// flag beside the status. Reading it, a house or door to do or nobody home
// with a come-back becomes « comeBack » (a done one never had a come-back);
// a building keeps its own.
//
// Versions 1 and 2 (up to T1.19) held a free `note` on each house and door.
// Notes were removed for privacy (PLAN §8.3, Q23): reading an older file
// ignores them, so the street comes back without any. The file is written
// again in version 3 as soon as it is read (see `LocalStreetRepository`),
// so no note stays on the phone. Every other mark is kept.
//
// Until #81, `comeBack` held a free hint (« après 19h »), in every version.
// The time replaced it without a new version: such a text reads as
// « repasser » with no time set (`comeBackFrom`), and goes from the file
// the next time the street is written.
//
// `shape` (one encoded polyline per line, see `StreetShape.encode`) and
// `assignees` came with the map (T3.3) without a new version: they only
// add to version 3, so a file written before reads as a street without
// shape that nobody covers, and nothing in it needs rewriting. `tries`
// (the tries with nobody home, #80) came the same way: written only from
// the first try, a missing one reads as none (and a « personne » without
// it as its first try, see `NobodyHomeTries.keptBy`).
//
// Statuses and label styles are written under fixed names chosen here, not
// the Dart enum names, so renaming an enum value in the code cannot make
// the streets already on a phone unreadable.
//
// Reading goes back through the domain's own checks (Street.create,
// Building.create, ComeBack.create…), so stored data can never build a street
// that breaks an invariant. Anything unreadable makes the whole street
// unreadable (a FormatException): dropping one house silently would lose
// its marks.
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/shared/mappers/come_back_text.dart';

/// The schema version this code writes. It reads it and versions 1 and 2
/// (see the top of this file); a file of any other version is refused
/// rather than misread.
const storedStreetVersion = 3;

/// The first schema, where « repasser » was a flag beside the status.
const _flagVersion = 1;

/// The schema where « repasser » became a status, and notes were still
/// kept.
const _noteVersion = 2;

/// Whether [json] is a street stored in a schema older than
/// [storedStreetVersion], which the storage must write again so nothing the
/// app dropped since (the notes of version 2) stays on the disk.
bool isOlderStoredStreet(Object? json) => switch (json) {
  {'version': final int version} => version < storedStreetVersion,
  _ => false,
};

/// The stored form of [street], ready for `jsonEncode`.
Map<String, Object?> streetToJson(Street street) => {
  'version': storedStreetVersion,
  'id': street.id.value,
  'name': street.name.text,
  'commune': {
    'inseeCode': street.commune.inseeCode.value,
    'name': street.commune.name,
  },
  'banId': street.banId?.value,
  'deletion': _stampToJson(street.deletion),
  'shape': street.shape.encode(),
  // Sorted, so the same street always makes the same file.
  'assignees': [for (final member in street.assignees) member.value]..sort(),
  'houses': [for (final house in street.houses) _houseToJson(house)],
  'removedHouses': [
    for (final removed in street.removedHouses)
      {
        'house': _houseToJson(removed.house),
        'removal': _stampToJson(removed.removal),
      },
  ],
};

/// The street stored as [json] (as `jsonDecode` gives it).
///
/// Throws a [FormatException] when [json] is not a street of
/// [storedStreetVersion], 2 or 1, or holds a value the domain refuses.
Street streetFromJson(Object? json) {
  if (json case {
    // `&&` and `||` combine patterns: the version is named, and must be
    // one of the constants this code knows.
    'version':
        final int version &&
        (storedStreetVersion || _noteVersion || _flagVersion),
    'id': final String id,
    'name': final String name,
    'commune': {
      'inseeCode': final String inseeCode,
      'name': final String communeName,
    },
    'banId': final String? banId,
    'deletion': final Object? deletion,
    'houses': final List<Object?> houses,
    'removedHouses': final List<Object?> removedHouses,
  }) {
    return _valid(
      Street.create(
        id: _identifier(id, StreetId.new),
        name: name,
        commune: _valid(
          Commune.create(inseeCode: inseeCode, name: communeName),
          'commune',
        ),
        banId: banId == null ? null : _identifier(banId, BanStreetId.new),
        // Read apart: a map pattern requires its keys, and files written
        // before the map have neither.
        shape: _shapeFromJson(json['shape']),
        assignees: _assigneesFromJson(json['assignees']),
        houses: [for (final house in houses) _houseFromJson(house, version)],
        removedHouses: [
          for (final removed in removedHouses)
            _removedFromJson(removed, version),
        ],
        deletion: _stampOrNull(deletion),
      ),
      'street',
    );
  }
  throw const FormatException('Not a stored street of this version');
}

/// The shape stored as [json]; none when the field is missing.
StreetShape _shapeFromJson(Object? json) => switch (json) {
  null => StreetShape.none,
  final List<Object?> lines => _valid(
    StreetShape.decode([
      for (final line in lines)
        line is String
            ? line
            : throw const FormatException('Not a stored line of a shape'),
    ]),
    'shape',
  ),
  _ => throw const FormatException('Not a stored shape'),
};

/// The members stored as [json]; nobody when the field is missing.
Set<MemberId> _assigneesFromJson(Object? json) => switch (json) {
  null => const {},
  final List<Object?> ids => {
    for (final id in ids)
      id is String
          ? _identifier(id, MemberId.new)
          : throw const FormatException('Not a stored assignee'),
  },
  _ => throw const FormatException('Not stored assignees'),
};

Map<String, Object?> _houseToJson(House house) => {
  'number': house.number.label,
  'status': _statusToJson(house.status),
  'comeBack': _comeBackToJson(house.comeBack),
  'lastChange': _stampToJson(house.lastChange),
  ..._triesToJson(house.tries),
  'position': switch (house.position) {
    null => null,
    final GeoPoint point => {
      'latitude': point.latitude,
      'longitude': point.longitude,
    },
  },
  'building': switch (house.building) {
    null => null,
    final Building building => _buildingToJson(building),
  },
};

/// A map pattern matches a map holding *at least* the keys it names, so the
/// `note` of a version 1 or 2 house or door is simply not read: it is
/// dropped.
House _houseFromJson(Object? json, int version) {
  if (json
      case final Map<String, Object?> house &&
          {
            'number': final String number,
            'status': final String status,
            'comeBack': final String? comeBack,
            'lastChange': final Object? lastChange,
            'position': final Object? position,
            'building': final Object? building,
          }) {
    return House(
      number: _valid(HouseNumber.parse(number), 'house number'),
      // On a building the House factory makes it to do again, keeping the
      // come-back as the building's own.
      status: _statusFromJson(status, comeBack: comeBack, version: version),
      comeBack: _comeBackOrNull(comeBack),
      lastChange: _stampOrNull(lastChange),
      position: position == null ? null : _positionFromJson(position),
      building: building == null ? null : _buildingFromJson(building, version),
      tries: _triesFromJson(house['tries']),
    );
  }
  throw const FormatException('Not a stored house');
}

RemovedHouse _removedFromJson(Object? json, int version) {
  if (json case {
    'house': final Object? house,
    'removal': final Object? stamp,
  }) {
    return RemovedHouse(
      house: _houseFromJson(house, version),
      removal: _stamp(stamp),
    );
  }
  throw const FormatException('Not a stored removed house');
}

GeoPoint _positionFromJson(Object json) {
  // `num` matches both an int and a double: `jsonDecode` reads `46` as an
  // int and `45.98` as a double.
  if (json case {
    'latitude': final num latitude,
    'longitude': final num longitude,
  }) {
    return _valid(
      GeoPoint.create(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
      'position',
    );
  }
  throw const FormatException('Not a stored position');
}

Map<String, Object?> _buildingToJson(Building building) => {
  'style': _styleToJson(building.style),
  'staircases': [
    for (final staircase in building.staircases)
      {
        'name': staircase.name.letter,
        'floors': [
          for (final floor in staircase.floors)
            {
              'level': floor.level,
              'dwellings': [
                for (final dwelling in floor.dwellings)
                  _dwellingToJson(dwelling),
              ],
            },
        ],
      },
  ],
};

Building _buildingFromJson(Object json, int version) {
  if (json case {
    'style': final String style,
    'staircases': final List<Object?> staircases,
  }) {
    return _valid(
      Building.create(
        style: _styleFromJson(style),
        staircases: [
          for (final staircase in staircases)
            _staircaseFromJson(staircase, version),
        ],
      ),
      'building',
    );
  }
  throw const FormatException('Not a stored building');
}

Staircase _staircaseFromJson(Object? json, int version) {
  if (json case {
    'name': final String name,
    'floors': final List<Object?> floors,
  }) {
    return Staircase(
      name: _identifier(name, StaircaseName.new),
      floors: [for (final floor in floors) _floorFromJson(floor, version)],
    );
  }
  throw const FormatException('Not a stored staircase');
}

Floor _floorFromJson(Object? json, int version) {
  if (json case {
    'level': final int? level,
    'dwellings': final List<Object?> dwellings,
  }) {
    return Floor(
      level: level,
      dwellings: [
        for (final dwelling in dwellings) _dwellingFromJson(dwelling, version),
      ],
    );
  }
  throw const FormatException('Not a stored floor');
}

Map<String, Object?> _dwellingToJson(Dwelling dwelling) => {
  'label': dwelling.label.text,
  'status': _statusToJson(dwelling.status),
  'comeBack': _comeBackToJson(dwelling.comeBack),
  'lastChange': _stampToJson(dwelling.lastChange),
  ..._triesToJson(dwelling.tries),
};

Dwelling _dwellingFromJson(Object? json, int version) {
  if (json
      case final Map<String, Object?> dwelling &&
          {
            'label': final String label,
            'status': final String status,
            'comeBack': final String? comeBack,
            'lastChange': final Object? lastChange,
          }) {
    return Dwelling(
      label: _valid(DwellingLabel.parse(label), 'door label'),
      status: _statusFromJson(status, comeBack: comeBack, version: version),
      comeBack: _comeBackOrNull(comeBack),
      lastChange: _stampOrNull(lastChange),
      tries: _triesFromJson(dwelling['tries']),
    );
  }
  throw const FormatException('Not a stored door');
}

/// The `tries` of a house or door: none before the first try.
Map<String, Object?> _triesToJson(NobodyHomeTries tries) => {
  if (tries.count > 0) 'tries': tries.count,
};

/// The tries stored as [json]; none when there is no `tries`.
NobodyHomeTries _triesFromJson(Object? json) => switch (json) {
  null => NobodyHomeTries.none,
  final int count => _valid(NobodyHomeTries.create(count), 'tries'),
  _ => throw const FormatException('Not stored tries'),
};

Map<String, Object?>? _stampToJson(ChangeStamp? stamp) => switch (stamp) {
  null => null,
  // Always UTC, so the text has one form whatever the phone's time zone.
  final ChangeStamp stamp => {
    'by': stamp.by.value,
    'at': stamp.at.toUtc().toIso8601String(),
  },
};

ChangeStamp? _stampOrNull(Object? json) => json == null ? null : _stamp(json);

ChangeStamp _stamp(Object? json) {
  if (json case {'by': final String by, 'at': final String at}) {
    final time = DateTime.tryParse(at);
    if (time == null) throw FormatException('Not a stored time', at);
    return ChangeStamp(by: _identifier(by, MemberId.new), at: time.toUtc());
  }
  throw const FormatException('Not a stored stamp');
}

String? _comeBackToJson(ComeBack? comeBack) =>
    comeBack == null ? null : comeBackText(comeBack);

ComeBack? _comeBackOrNull(String? text) =>
    text == null ? null : comeBackFrom(text);

String _statusToJson(VisitStatus status) => switch (status) {
  VisitStatus.toDo => 'toDo',
  VisitStatus.done => 'done',
  VisitStatus.nobodyHome => 'nobodyHome',
  VisitStatus.comeBack => 'comeBack',
};

/// The status stored as [text], next to the stored [comeBack], in a
/// file of schema [version]. In version 1 a come-back on a house or door
/// not done was the « repasser » flag: it is that status now.
VisitStatus _statusFromJson(
  String text, {
  required String? comeBack,
  required int version,
}) {
  final status = switch (text) {
    'toDo' => VisitStatus.toDo,
    'done' => VisitStatus.done,
    'nobodyHome' => VisitStatus.nobodyHome,
    'comeBack' when version != _flagVersion => VisitStatus.comeBack,
    _ => throw FormatException('Not a stored status', text),
  };
  final wasFlagged =
      version == _flagVersion && comeBack != null && status != VisitStatus.done;
  return wasFlagged ? VisitStatus.comeBack : status;
}

String _styleToJson(DoorLabelStyle style) => switch (style) {
  DoorLabelStyle.floorAndNumber => 'floorAndNumber',
  DoorLabelStyle.floorAndLetter => 'floorAndLetter',
  DoorLabelStyle.free => 'free',
};

DoorLabelStyle _styleFromJson(String text) => switch (text) {
  'floorAndNumber' => DoorLabelStyle.floorAndNumber,
  'floorAndLetter' => DoorLabelStyle.floorAndLetter,
  'free' => DoorLabelStyle.free,
  _ => throw FormatException('Not a stored door label style', text),
};

/// The value of [result], or a [FormatException] naming [what] was
/// refused: stored data the domain refuses is unreadable data.
T _valid<T, F>(Result<T, F> result, String what) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw FormatException('Invalid $what: $failure'),
};

/// The identifier [make] builds from [text]. Identifier constructors throw
/// an [ArgumentError] on a value no adapter should make (a blank id, a
/// staircase `a`): in code it is a bug, but in a stored file it is
/// unreadable data, so it becomes a [FormatException].
T _identifier<T>(String text, T Function(String) make) {
  try {
    return make(text);
  } on ArgumentError {
    throw FormatException('Not a stored identifier', text);
  }
}
