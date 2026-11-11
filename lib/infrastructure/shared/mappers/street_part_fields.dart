// How the part of a street a secteur holds is stored, in Firestore (`part`
// on the street document, PLAN §6.2) and in the phone's files (§6.3)
// alike:
//
//   part = { odd: side, even: side }      ← absent: the whole street
//   side = "all" | "none" | [from, to]    ← bounds on the integer part
//
// The whole street is never written: a street without the field reads as
// whole, so the documents and files written before #133 need nothing, and
// a part back to « Toute la rue » removes the field. The security rules
// check the same shape (PLAN §8.2). Pure functions, tested alone.
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

/// The stored form of [part]; null for the whole street, which is stored
/// as no field at all.
Map<String, Object?>? storedPart(StreetPart part) =>
    part.isWhole ? null : storedSides(part);

/// Both sides of [part] in their stored form, the whole street included
/// (`{ odd: "all", even: "all" }`): an entry of the shared index of the
/// secteurs' parts always says both (PLAN §6.2 `streetParts/{banId}`).
Map<String, Object?> storedSides(StreetPart part) => {
  'odd': _storedSide(part.odd),
  'even': _storedSide(part.even),
};

Object _storedSide(SidePart side) => switch (side) {
  AllNumbers() => 'all',
  NoNumbers() => 'none',
  NumberRange(:final from, :final to) => [from, to],
};

/// The part stored as [json]: the whole street when the field is missing
/// (or null).
///
/// Throws a [FormatException] when [json] is not a stored part, or holds
/// one the domain refuses (a bound on the other side).
StreetPart partFrom(Object? json) => switch (json) {
  null => StreetPart.whole,
  {'odd': final Object? odd, 'even': final Object? even} =>
    switch (StreetPart.create(odd: _sideFrom(odd), even: _sideFrom(even))) {
      Ok(:final value) => value,
      Err(:final failure) => throw FormatException('Invalid part: $failure'),
    },
  _ => throw FormatException('Not a stored part', json),
};

SidePart _sideFrom(Object? json) => switch (json) {
  'all' => SidePart.all,
  'none' => SidePart.none,
  [final int from, final int to] => switch (SidePart.range(from, to)) {
    Ok(:final value) => value,
    Err(:final failure) => throw FormatException('Invalid side: $failure'),
  },
  _ => throw FormatException('Not a stored side of a part', json),
};
