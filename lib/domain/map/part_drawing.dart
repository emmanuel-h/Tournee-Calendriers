import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// What the map of « Partie de la rue » draws (PLAN §5.15, StreetPart
/// mockup), as plain data: the road in grey, the stretch kept as the
/// selected road, a dot per house with a position, and the two marks with
/// the points they may snap to. `ui/map/` only turns it into MapLibre
/// sources and layers, and the marks into handles.
final class PartDrawing {
  PartDrawing({
    required this.road,
    required this.kept,
    required List<PartDot> dots,
    required List<GeoPoint> gaps,
    required this.first,
    required this.last,
    required this.area,
  }) : dots = List.unmodifiable(dots),
       gaps = List.unmodifiable(gaps);

  /// The whole road, drawn grey.
  final StreetShape road;

  /// The stretch between the two marks, drawn as the selected road (dark
  /// casing, white core); none when the marks meet.
  final StreetShape kept;

  /// A dot per number with a position, by number.
  final List<PartDot> dots;

  /// Where a mark may stand, along the road: before the first dot of the
  /// side shown, between each two consecutive dots, after the last. A
  /// mark's [PartMarkAt.gap] is an index in this list. Empty when the side
  /// shown has no dot: then there is no mark.
  final List<GeoPoint> gaps;

  /// The two marks; null when the side shown has no dot.
  final PartMarkAt? first;
  final PartMarkAt? last;

  /// What the map shows: the road and every dot.
  final GeoBounds area;
}

/// How a house dot of « Partie de la rue » looks.
enum PartDotLook {
  /// In the part, on the side shown: ink.
  kept,

  /// Out of the part, on the side shown: hollow.
  leftOut,

  /// On the other side than the one shown: greyed.
  otherSide,
}

/// A house of « Partie de la rue » at its [position], with its [look].
final class PartDot {
  const PartDot({
    required this.number,
    required this.position,
    required this.look,
  });

  final HouseNumber number;
  final GeoPoint position;
  final PartDotLook look;

  @override
  bool operator ==(Object other) =>
      other is PartDot &&
      other.number == number &&
      other.position == position &&
      other.look == look;

  @override
  int get hashCode => Object.hash(number, position, look);

  @override
  String toString() => 'PartDot(${number.label}, ${look.name})';
}

/// One of the two marks of « Partie de la rue », at the [gap]-th place of
/// [PartDrawing.gaps], which is [point], and between the dots its [place]
/// names.
final class PartMarkAt {
  const PartMarkAt({
    required this.gap,
    required this.point,
    required this.place,
  });

  final int gap;
  final GeoPoint point;
  final MarkPlace place;
}

/// Where a mark stands, by the numbers of the dots around it: its label
/// (« entre 5 et 7 »). `sealed`: the screen words each case.
sealed class MarkPlace {
  const MarkPlace();
}

/// Before the first dot along the road, numbered [number].
final class MarkBefore extends MarkPlace {
  const MarkBefore(this.number);

  final int number;

  @override
  bool operator ==(Object other) =>
      other is MarkBefore && other.number == number;

  @override
  int get hashCode => Object.hash(MarkBefore, number);

  @override
  String toString() => 'MarkBefore($number)';
}

/// Between two consecutive dots along the road, numbered [before] and
/// [after] in the order of the road.
final class MarkBetween extends MarkPlace {
  const MarkBetween(this.before, this.after);

  final int before;
  final int after;

  @override
  bool operator ==(Object other) =>
      other is MarkBetween && other.before == before && other.after == after;

  @override
  int get hashCode => Object.hash(before, after);

  @override
  String toString() => 'MarkBetween($before, $after)';
}

/// After the last dot along the road, numbered [number].
final class MarkAfter extends MarkPlace {
  const MarkAfter(this.number);

  final int number;

  @override
  bool operator ==(Object other) =>
      other is MarkAfter && other.number == number;

  @override
  int get hashCode => Object.hash(MarkAfter, number);

  @override
  String toString() => 'MarkAfter($number)';
}
