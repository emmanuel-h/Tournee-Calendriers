import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// Where a « repasser » is (PLAN §5.17): the house [number] of the
/// [street], or the [door] of that building; a building's own
/// « Repasser » has no door.
///
/// What « À repasser » opens and what a reminder leads to: the street at
/// that house, or the building's grid at that door.
final class ComeBackPlace {
  const ComeBackPlace({required this.street, required this.number, this.door});

  final StreetId street;
  final HouseNumber number;

  /// The door of the building [number]; null for a single house, or for
  /// the building's own « Repasser ».
  final DwellingKey? door;

  @override
  bool operator ==(Object other) =>
      other is ComeBackPlace &&
      other.street == street &&
      other.number == number &&
      other.door == door;

  @override
  int get hashCode => Object.hash(street, number, door);

  @override
  String toString() => [
    'ComeBackPlace(${street.value}, ${number.label}',
    if (door case final door?) ', ${door.id}',
    ')',
  ].join();
}

/// One « repasser » of the secteur, as « À repasser » lists it and the
/// reminders read it (PLAN §5.17): where ([place], on the street named
/// [streetName]), when ([comeBack]) and who set it last ([setBy], the
/// last change of the house, door or building; null when nobody is
/// known).
///
/// A read model: it is worked out from the streets ([ComeBackEntry.allOf])
/// each time they change, never stored.
final class ComeBackEntry {
  const ComeBackEntry({
    required this.place,
    required this.streetName,
    required this.comeBack,
    this.setBy,
  });

  final ComeBackPlace place;
  final StreetName streetName;
  final ComeBack comeBack;
  final ChangeStamp? setBy;

  /// Every « repasser » of [streets]: each single house « repasser », each
  /// door « repasser », and each building with its own « Repasser »
  /// (PLAN §5.7). In the order of the streets, then of their houses, then
  /// of the doors from the top floor down.
  static List<ComeBackEntry> allOf(Iterable<Street> streets) => [
    for (final street in streets)
      for (final house in street.houses) ...[
        if (house.comeBack case final comeBack?)
          ComeBackEntry(
            place: ComeBackPlace(street: street.id, number: house.number),
            streetName: street.name,
            comeBack: comeBack,
            setBy: house.lastChange,
          ),
        if (house.building case final building?)
          for (final staircase in building.staircases)
            for (final floor in staircase.floors)
              for (final dwelling in floor.dwellings)
                if (dwelling.comeBack case final comeBack?)
                  ComeBackEntry(
                    place: ComeBackPlace(
                      street: street.id,
                      number: house.number,
                      door: DwellingKey(
                        staircase.name,
                        floor.level,
                        dwelling.label,
                      ),
                    ),
                    streetName: street.name,
                    comeBack: comeBack,
                    setBy: dwelling.lastChange,
                  ),
      ],
  ];

  /// Orders two « repasser » by address: street name the French way, then
  /// number, then the house before its doors and the doors by id; by
  /// street id among equals, so the order never depends on the sort.
  static int byAddress(ComeBackEntry a, ComeBackEntry b) {
    final byName = compareFrench(a.streetName.text, b.streetName.text);
    if (byName != 0) return byName;
    final byNumber = a.place.number.compareTo(b.place.number);
    if (byNumber != 0) return byNumber;
    final byDoor = (a.place.door?.id ?? '').compareTo(b.place.door?.id ?? '');
    if (byDoor != 0) return byDoor;
    return a.place.street.value.compareTo(b.place.street.value);
  }

  /// Whether [member] set it: its last change is theirs. Only those ring
  /// on [member]'s phone (PLAN §5.17).
  bool isSetBy(MemberId member) => setBy?.by == member;

  @override
  bool operator ==(Object other) =>
      other is ComeBackEntry &&
      other.place == place &&
      other.streetName == streetName &&
      other.comeBack == comeBack &&
      other.setBy == setBy;

  @override
  int get hashCode => Object.hash(place, streetName, comeBack, setBy);

  @override
  String toString() =>
      'ComeBackEntry($place, ${streetName.text}, $comeBack, $setBy)';
}
