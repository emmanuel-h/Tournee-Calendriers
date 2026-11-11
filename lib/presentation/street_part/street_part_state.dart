import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';

// The view state of « Partie de la rue » (PLAN §5.15, StreetPart mockup).

/// What « Partie de la rue » opens with: the street's name, for the title,
/// and the choice it starts from (the street's numbers with their
/// positions, its road and its part). Edit mode reads it with
/// `ReadStreetPartChoice`; « Ajouter des rues » makes it from the BAN's
/// numbers before the street is added.
///
/// Compared by identity (no `==`): each opening of the screen is its own,
/// with its own state, even for the same street.
final class StreetPartRequest {
  const StreetPartRequest({required this.streetName, required this.choice});

  final String streetName;
  final StreetPartChoice choice;
}

/// Everything « Partie de la rue » shows.
final class StreetPartView {
  const StreetPartView({
    required this.streetName,
    required this.lowest,
    required this.highest,
    required this.side,
    required this.part,
    required this.keptCount,
    required this.numberCount,
    required this.drawing,
    required this.bounds,
  });

  /// The view of [choice], for the street named [streetName].
  factory StreetPartView.of(String streetName, StreetPartChoice choice) =>
      StreetPartView(
        streetName: streetName,
        lowest: choice.lowest,
        highest: choice.highest,
        side: choice.side,
        part: choice.part,
        keptCount: choice.keptCount,
        numberCount: choice.numberCount,
        drawing: choice.drawing,
        bounds: choice.bounds,
      );

  /// Under the title: « Rue Nationale · n° 1 à 41 ».
  final String streetName;
  final int? lowest;
  final int? highest;

  /// « Les deux | Impairs | Pairs ».
  final Sides side;

  /// The part chosen so far: « Impairs 7–21 · pairs 2–30 ».
  final StreetPart part;

  /// « 23 numéros gardés sur 41 ».
  final int keptCount;
  final int numberCount;

  /// The map, or null for a street without positions: then « Du n° » and
  /// « Au n° » choose the part.
  final PartDrawing? drawing;

  /// What « Du n° » and « Au n° » show when the side changes.
  final ({int? from, int? to}) bounds;
}
