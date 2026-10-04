// Translation between a Street and the JSON the phone storage keeps for it
// (M1, until Firestore replaces that storage in M2). Pure functions: no file
// here, so they are tested alone.
//
// The schema, version 1 (PLAN §6.3):
//
//   { version: 1, id, name, commune: { inseeCode, name }, banId | null,
//     deletion: stamp | null, houses: [house], removedHouses: [{ house,
//     removal: stamp }] }
//   house    = { number: "3bis", status, comeBack: hint | null, note,
//                lastChange: stamp | null,
//                position: { latitude, longitude } | null,
//                building: building | null }
//   building = { style, staircases: [{ name: "A", floors: [{ level | null,
//                dwellings: [{ label, status, comeBack, note,
//                              lastChange }] }] }] }
//   stamp    = { by: memberId, at: "2026-11-02T14:02:00.000Z" }  (UTC)
//
// Statuses and label styles are written under fixed names chosen here, not
// the Dart enum names, so renaming an enum value in the code cannot make
// the streets already on a phone unreadable.
//
// Reading goes back through the domain's own checks (Street.create,
// Building.create, Note.create…), so stored data can never build a street
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
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// The schema version this code writes and reads. A file of another version
/// is refused rather than misread; a later version that changes the schema
/// reads the older ones and writes its own.
const storedStreetVersion = 1;

/// The stored form of [street], ready for `jsonEncode`.
Map<String, Object?> streetToJson(Street street) => {
  'version': storedStreetVersion,
  'id': street.id.value,
  'name': street.name,
  'commune': {
    'inseeCode': street.commune.inseeCode,
    'name': street.commune.name,
  },
  'banId': street.banId?.value,
  'deletion': _stampToJson(street.deletion),
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
/// [storedStreetVersion], or holds a value the domain refuses.
Street streetFromJson(Object? json) {
  if (json case {
    // A constant inside a pattern matches only that value.
    'version': storedStreetVersion,
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
        houses: [for (final house in houses) _houseFromJson(house)],
        removedHouses: [
          for (final removed in removedHouses) _removedFromJson(removed),
        ],
        deletion: _stampOrNull(deletion),
      ),
      'street',
    );
  }
  throw const FormatException('Not a stored street of this version');
}

Map<String, Object?> _houseToJson(House house) => {
  'number': house.number.label,
  'status': _statusToJson(house.status),
  'comeBack': house.comeBack?.hint,
  'note': house.note.text,
  'lastChange': _stampToJson(house.lastChange),
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

House _houseFromJson(Object? json) {
  if (json case {
    'number': final String number,
    'status': final String status,
    'comeBack': final String? comeBack,
    'note': final String note,
    'lastChange': final Object? lastChange,
    'position': final Object? position,
    'building': final Object? building,
  }) {
    return House(
      number: _valid(HouseNumber.parse(number), 'house number'),
      status: _statusFromJson(status),
      comeBack: _comeBackOrNull(comeBack),
      note: _valid(Note.create(note), 'note'),
      lastChange: _stampOrNull(lastChange),
      position: position == null ? null : _positionFromJson(position),
      building: building == null ? null : _buildingFromJson(building),
    );
  }
  throw const FormatException('Not a stored house');
}

RemovedHouse _removedFromJson(Object? json) {
  if (json case {
    'house': final Object? house,
    'removal': final Object? stamp,
  }) {
    return RemovedHouse(house: _houseFromJson(house), removal: _stamp(stamp));
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

Building _buildingFromJson(Object json) {
  if (json case {
    'style': final String style,
    'staircases': final List<Object?> staircases,
  }) {
    return _valid(
      Building.create(
        style: _styleFromJson(style),
        staircases: [
          for (final staircase in staircases) _staircaseFromJson(staircase),
        ],
      ),
      'building',
    );
  }
  throw const FormatException('Not a stored building');
}

Staircase _staircaseFromJson(Object? json) {
  if (json case {
    'name': final String name,
    'floors': final List<Object?> floors,
  }) {
    return Staircase(
      name: _identifier(name, StaircaseName.new),
      floors: [for (final floor in floors) _floorFromJson(floor)],
    );
  }
  throw const FormatException('Not a stored staircase');
}

Floor _floorFromJson(Object? json) {
  if (json case {
    'level': final int? level,
    'dwellings': final List<Object?> dwellings,
  }) {
    return Floor(
      level: level,
      dwellings: [
        for (final dwelling in dwellings) _dwellingFromJson(dwelling),
      ],
    );
  }
  throw const FormatException('Not a stored floor');
}

Map<String, Object?> _dwellingToJson(Dwelling dwelling) => {
  'label': dwelling.label.text,
  'status': _statusToJson(dwelling.status),
  'comeBack': dwelling.comeBack?.hint,
  'note': dwelling.note.text,
  'lastChange': _stampToJson(dwelling.lastChange),
};

Dwelling _dwellingFromJson(Object? json) {
  if (json case {
    'label': final String label,
    'status': final String status,
    'comeBack': final String? comeBack,
    'note': final String note,
    'lastChange': final Object? lastChange,
  }) {
    return Dwelling(
      label: _valid(DwellingLabel.parse(label), 'door label'),
      status: _statusFromJson(status),
      comeBack: _comeBackOrNull(comeBack),
      note: _valid(Note.create(note), 'note'),
      lastChange: _stampOrNull(lastChange),
    );
  }
  throw const FormatException('Not a stored door');
}

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

ComeBack? _comeBackOrNull(String? hint) =>
    hint == null ? null : _valid(ComeBack.create(hint), '« repasser » hint');

String _statusToJson(VisitStatus status) => switch (status) {
  VisitStatus.toDo => 'toDo',
  VisitStatus.done => 'done',
  VisitStatus.nobodyHome => 'nobodyHome',
};

VisitStatus _statusFromJson(String text) => switch (text) {
  'toDo' => VisitStatus.toDo,
  'done' => VisitStatus.done,
  'nobodyHome' => VisitStatus.nobodyHome,
  _ => throw FormatException('Not a stored status', text),
};

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
