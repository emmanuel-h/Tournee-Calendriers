import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

// What the screens say of the other secteurs holding a street (PLAN §5.15
// « Other secteurs »), shared by « Partie de la rue » and the rows of
// « Ajouter des rues ». The centre de secours is named only when it is not
// the open secteur's: « secteur 12 » among the secteurs of one station,
// « secteur 12 (CS Arnas) » for another station's.

/// The line under a street to add that another secteur holds in part:
/// « Secteur 12 : impairs 19–41 ».
final class OtherSectorLine {
  const OtherSectorLine({
    required this.sector,
    required this.part,
    this.centre,
  });

  /// The lines of [others], the open secteur's centre being [ours] (null
  /// when no secteur is open: every centre is then named).
  static List<OtherSectorLine> of(
    List<SectorPart> others,
    RescueCentre? ours,
  ) => [
    for (final other in others)
      OtherSectorLine(
        sector: other.sector.value,
        centre: centreToSay(other.centre, ours),
        part: other.part,
      ),
  ];

  final int sector;

  /// The other secteur's centre, null when it is the open secteur's.
  final String? centre;

  final StreetPart part;

  @override
  bool operator ==(Object other) =>
      other is OtherSectorLine &&
      other.sector == sector &&
      other.centre == centre &&
      other.part == part;

  @override
  int get hashCode => Object.hash(sector, centre, part);

  @override
  String toString() => 'OtherSectorLine($sector, $centre, $part)';
}

/// The warning of « Partie de la rue »: « Le 19 et le 21 sont aussi dans
/// le secteur 12 (CS Villefranche). ».
final class OverlapLine {
  OverlapLine({
    required this.sector,
    required List<String> numbers,
    this.centre,
  }) : numbers = List.unmodifiable(numbers);

  /// The lines of [overlaps], the open secteur's centre being [ours].
  static List<OverlapLine> of(List<PartOverlap> overlaps, RescueCentre? ours) =>
      [
        for (final overlap in overlaps)
          OverlapLine(
            sector: overlap.other.sector.value,
            centre: centreToSay(overlap.other.centre, ours),
            numbers: [for (final number in overlap.numbers) number.label],
          ),
      ];

  final int sector;

  /// The other secteur's centre, null when it is the open secteur's.
  final String? centre;

  /// The numbers both hold, by their labels, in street order; never empty.
  /// Read-only.
  final List<String> numbers;

  @override
  bool operator ==(Object other) =>
      other is OverlapLine &&
      other.sector == sector &&
      other.centre == centre &&
      sameItems(other.numbers, numbers);

  @override
  int get hashCode => Object.hash(sector, centre, Object.hashAll(numbers));

  @override
  String toString() => 'OverlapLine($sector, $centre, $numbers)';
}

/// The name of the centre [other] to say beside a secteur's number: null
/// when it is the same station as [ours].
String? centreToSay(RescueCentre other, RescueCentre? ours) =>
    ours != null && other.isSameStationAs(ours) ? null : other.name;
