// The Firestore updates that store one change of a street (PLAN §6.2): the
// field paths the change names, each with its new value, so two people
// changing different houses or doors of the same street at the same moment
// never overwrite each other. Pure functions, tested alone.
//
// The paths are `FieldPath` segments, never dotted text: a door label is
// typed by people and may hold a dot (`houses.10.dwellings.A-Porte 1.2`
// would read as one level too many).
//
// The values come from the street after the change: the change says which
// fields changed, the street what they hold now, so no rule of the domain
// is repeated here. Two writes never rely on a map being replaced whole,
// because a write of a map at a path *replaces* it in Firestore but would
// be merged by a careless reader of this code (and by the in-memory fake
// the tests use): a building is written door by door, the doors a new
// layout drops are removed one by one.
//
// A field the entry of a house or door leaves out is removed: `tries` is
// stored only from the first try (see street_document_mapper.dart), so a
// house to do again loses the field rather than holding 0.
//
// An undo writes the house or door back as it was, with one exception: it
// is stamped with who undoes and when, not with the old stamp, since the
// security rules accept only the caller's own uid as `by` (PLAN §8.2).
import 'package:cloud_firestore/cloud_firestore.dart' show FieldPath;
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

/// The updates storing [change], which made [street], in the order they
/// are sent: each field path with its new value, ready for
/// `DocumentReference.update`.
///
/// One update per change, except « numéros en plus » bringing numbers back
/// from the Corbeille: the new houses go in one update and each number
/// restored in one of its own; and the purge, one update per number. The security rules check field by field a
/// write that changes one house already there, and only count the houses
/// a write adds; they refuse a write that changes several houses already
/// there, since they cannot check them one by one (PLAN §8.2).
///
/// [undoStamp] (who is undoing, now) stamps what an undo puts back.
/// [removal] is the value that removes a field, `FieldValue.delete()`;
/// [arrayUnion] and [arrayRemove] make the values that add one item to an
/// array, or remove it, leaving the others (`FieldValue.arrayUnion([item])`,
/// `FieldValue.arrayRemove([item])`). They are passed in so this mapping
/// needs no Firestore platform and its tests can recognise them.
List<Map<FieldPath, Object?>> streetUpdates(
  Street street,
  StreetChange change, {
  required ChangeStamp undoStamp,
  required Object removal,
  required Object Function(Object item) arrayUnion,
  required Object Function(Object item) arrayRemove,
}) {
  Map<FieldPath, Object?> doorUpdate(
    HouseNumber number,
    DwellingKey key,
    List<String> fields,
  ) {
    final entry = dwellingEntry(
      _houseIn(street, number).building!.dwellingAt(key)!,
    );
    return {
      for (final field in fields)
        _path([_houses, number.label, _dwellings, key.id, field]): _valueOf(
          entry,
          field,
          removal,
        ),
    };
  }

  return switch (change) {
    HouseMarked(:final number) || HouseNobodyHomeAgain(:final number) => [
      _houseFields(street, number, _markFields, removal),
    ],
    ComeBackSet(:final number) => [
      _houseFields(street, number, const ['comeBack', 'by', 'at'], removal),
    ],
    BuildingLaidOut(:final before) || BuildingRemoved(:final before) => [
      _houseRewritten(before, _houseIn(street, before.number), removal),
    ],
    NumberRenamed(:final number, :final after) => [
      {
        _path([_houses, number.label]): removal,
        _path([_houses, after.number.label]): houseEntry(after),
      },
    ],
    DwellingMarked(:final number, :final key) ||
    DwellingNobodyHomeAgain(
      :final number,
      :final key,
    ) => [doorUpdate(number, key, _markFields)],
    DwellingComeBackSet(:final number, :final key) => [
      doorUpdate(number, key, const ['comeBack', 'by', 'at']),
    ],
    StreetDeleted(:final deletion) => [_stampUpdate([], deletion, 'deleted')],
    StreetRestored() => [_stampUpdate([], null, 'deleted')],
    // The member alone, never the whole array: a teammate taking the same
    // street at the same moment is not overwritten.
    StreetTaken(:final member) => [
      {
        _path([_assignees]): arrayUnion(member.value),
      },
    ],
    StreetReleased(:final member) => [
      {
        _path([_assignees]): arrayRemove(member.value),
      },
    ],
    NumbersAdded(:final added, :final restored) => [
      if (added.isNotEmpty)
        {
          for (final house in added)
            _path([_houses, house.number.label]): houseEntry(house),
        },
      for (final back in restored)
        _stampUpdate([_houses, back.number.label], null, 'deleted'),
    ],
    NumberRemoved(:final removed) => [
      _stampUpdate([_houses, removed.number.label], removed.removal, 'deleted'),
    ],
    NumberRestored(:final number) => [
      _stampUpdate([_houses, number.label], null, 'deleted'),
    ],
    // One house dropped per update: the security rules check the house a
    // write drops (removed more than 30 days ago), and cannot check several.
    NumbersPurged(:final numbers) => [
      for (final number in numbers)
        {
          _path([_houses, number.label]): removal,
        },
    ],
    StreetRenamed(:final name) => [
      {
        _path(['name']): name.text,
      },
    ],
    // The whole list, once: the security rules accept it only while the
    // stored shape is empty.
    StreetShapeFilled(:final shape) => [
      {
        _path(['shape']): shape.encode(),
      },
    ],
    // Before the general undo of a house: a `switch` takes the first case
    // that matches, and this one needs the key moved.
    HouseReverted(renumbers: true, :final replaced, :final house) => [
      {
        _path([_houses, replaced.number.label]): removal,
        _path([_houses, house.number.label]): houseEntry(
          _stamped(house, undoStamp),
        ),
      },
    ],
    HouseReverted(:final replaced, :final house) => [
      _houseRewritten(replaced, _stamped(house, undoStamp), removal),
    ],
    DwellingReverted(:final number, :final key, :final dwelling) => [
      {
        _path([_houses, number.label, _dwellings, key.id]): dwellingEntry(
          Dwelling(
            label: dwelling.label,
            status: dwelling.status,
            comeBack: dwelling.comeBack,
            lastChange: undoStamp,
            tries: dwelling.tries,
          ),
        ),
      },
    ],
  };
}

/// The fields a status changes on a house or a door: the status, its
/// « repasser » time, its tries with nobody home, and who changed it when.
const _markFields = ['status', 'comeBack', 'tries', 'by', 'at'];

const _houses = 'houses';
const _assignees = 'assignees';
const _dwellings = 'dwellings';

FieldPath _path(List<String> segments) => FieldPath(segments);

/// The house at [number] in [street]; the change just made it, so it is
/// there.
House _houseIn(Street street, HouseNumber number) => street.houseAt(number)!;

/// [fields] of the house at [number] of [street].
Map<FieldPath, Object?> _houseFields(
  Street street,
  HouseNumber number,
  List<String> fields,
  Object removal,
) {
  final entry = houseEntry(_houseIn(street, number));
  return {
    for (final field in fields)
      _path([_houses, number.label, field]): _valueOf(entry, field, removal),
  };
}

/// The value of [field] in [entry], or [removal] when the entry leaves it
/// out (`tries` before the first try).
Object? _valueOf(Map<String, Object?> entry, String field, Object removal) =>
    entry.containsKey(field) ? entry[field] : removal;

/// [after] written over [before], both under the same number: its status,
/// « repasser », tries and stamp, and its building door by door (the doors
/// [before] had and [after] has not are removed). The number, the position
/// and the removal do not change.
Map<FieldPath, Object?> _houseRewritten(
  House before,
  House after,
  Object removal,
) {
  final label = after.number.label;
  final entry = houseEntry(after);
  FieldPath field(String name) => _path([_houses, label, name]);
  final update = <FieldPath, Object?>{
    for (final name in _markFields) field(name): _valueOf(entry, name, removal),
  };
  final building = after.building;
  if (building == null) {
    if (before.building != null) {
      for (final name in const ['labelStyle', 'layout', _dwellings]) {
        update[field(name)] = removal;
      }
    }
    return update;
  }
  update[field('labelStyle')] = entry['labelStyle'];
  update[field('layout')] = entry['layout'];
  final kept = <String>{};
  for (final (key, dwelling) in doorsOf(building)) {
    kept.add(key.id);
    update[_path([_houses, label, _dwellings, key.id])] = dwellingEntry(
      dwelling,
    );
  }
  if (before.building case final old?) {
    for (final (key, _) in doorsOf(old)) {
      if (!kept.contains(key.id)) {
        update[_path([_houses, label, _dwellings, key.id])] = removal;
      }
    }
  }
  return update;
}

/// `<prefix>At` and `<prefix>By` under [segments], from [stamp] (null
/// clears them).
Map<FieldPath, Object?> _stampUpdate(
  List<String> segments,
  ChangeStamp? stamp,
  String prefix,
) {
  final fields = stampFields(stamp, by: '${prefix}By', at: '${prefix}At');
  return {
    for (final MapEntry(:key, :value) in fields.entries)
      _path([...segments, key]): value,
  };
}

/// [house] with [stamp] as its last change.
House _stamped(House house, ChangeStamp stamp) => House(
  number: house.number,
  status: house.status,
  comeBack: house.comeBack,
  lastChange: stamp,
  building: house.building,
  position: house.position,
  tries: house.tries,
);
