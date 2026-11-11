import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

/// What another secteur holds of a street, as the shared index tells it
/// (PLAN §5.15 « Other secteurs », §6.2 `streetParts/{banId}`): « Secteur
/// 12 (CS Villefranche) : impairs 19–41 ».
///
/// Only a hint: the index may be out of date, and a centre may want two
/// secteurs on the same numbers, so nothing is ever refused because of
/// it. An immutable value, equal to another with the same fields.
final class SectorPart {
  const SectorPart({
    required this.sector,
    required this.centre,
    required this.part,
  });

  /// The other secteur's number (« Secteur 12 »).
  final SectorNumber sector;

  /// Its centre de secours, said only when it is not this secteur's.
  final RescueCentre centre;

  /// The part of the street it holds.
  final StreetPart part;

  @override
  bool operator ==(Object other) =>
      other is SectorPart &&
      other.sector == sector &&
      other.centre == centre &&
      other.part == part;

  @override
  int get hashCode => Object.hash(sector, centre, part);

  @override
  String toString() =>
      'SectorPart(${sector.value}, ${centre.name}, ${part.odd}, '
      '${part.even})';
}

/// The numbers of a street that the part being chosen holds and that
/// [other] holds too: « Le 19 et le 21 sont aussi dans le secteur 12 ».
/// A warning, never a refusal (see [SectorPart]).
final class PartOverlap {
  PartOverlap({required this.other, required List<HouseNumber> numbers})
    : numbers = List.unmodifiable(numbers);

  final SectorPart other;

  /// The numbers both hold, in street order; never empty. Read-only.
  final List<HouseNumber> numbers;

  @override
  bool operator ==(Object other) =>
      other is PartOverlap &&
      other.other == this.other &&
      sameItems(other.numbers, numbers);

  @override
  int get hashCode => Object.hash(other, Object.hashAll(numbers));

  @override
  String toString() =>
      'PartOverlap(${other.sector.value}, '
      '${numbers.map((number) => number.label).join(', ')})';
}
