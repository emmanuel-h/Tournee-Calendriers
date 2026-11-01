import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/building/building_status.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/team_roster.dart';

/// What the map draws over its background for a tournée (PLAN §5.3), as
/// plain data: a line per street coloured by its [ProgressLevel], a dot per
/// house glyphed by its status. `ui/map/` only turns it into MapLibre
/// sources and layers; every choice of what is shown is made here.
final class MapLayers {
  const MapLayers._(this.lines, this.dots);

  /// The layers of [streets]. A street is « libre » while nobody covers
  /// it: no assignee the [roster] counts, so none still in the team (#91).
  /// The [roster] defaults to [TeamRoster.unknown], which trusts every
  /// assignee.
  ///
  /// Streets in the Corbeille are left out. A street without shape (typed
  /// in by hand, unknown to OpenStreetMap) has no line, and a house without
  /// position (typed in by hand) no dot: they appear only in the lists.
  factory MapLayers.of(
    Iterable<Street> streets, {
    TeamRoster roster = TeamRoster.unknown,
  }) {
    final shown = streets.where((street) => !street.isDeleted);
    return MapLayers._(
      List.unmodifiable([
        for (final street in shown)
          if (!street.shape.isEmpty)
            StreetLine(
              street: street.id,
              shape: street.shape,
              level: ProgressLevel.of(
                street.progress,
                taken: roster.isTaken(street),
              ),
            ),
      ]),
      List.unmodifiable([
        for (final street in shown)
          for (final house in street.houses)
            // A pattern in a collection `if`: `final position?` matches
            // only a non-null position, and names it without the `?`.
            if (house.position case final position?)
              HouseDot(
                street: street.id,
                number: house.number,
                position: position,
                status: HouseDotStatus.of(house),
              ),
      ]),
    );
  }

  /// The zoom level from which the house dots show (street zoom, PLAN
  /// §5.3); under it, only the street lines.
  static const houseDotsMinZoom = 16;

  /// Whether the map shows the house dots at [zoom]: then its legend
  /// explains the dots' statuses rather than the streets' colours.
  static bool showsHouseDots(double zoom) => zoom >= houseDotsMinZoom;

  /// One line per street with a shape, in the order of the streets. The
  /// list cannot be modified.
  final List<StreetLine> lines;

  /// One dot per house with a position, street after street, by number.
  /// The list cannot be modified.
  final List<HouseDot> dots;
}

/// A street drawn on the map: its [shape], coloured by its [level]. A tap
/// on it names the [street].
final class StreetLine {
  const StreetLine({
    required this.street,
    required this.shape,
    required this.level,
  });

  final StreetId street;
  final StreetShape shape;
  final ProgressLevel level;

  @override
  bool operator ==(Object other) =>
      other is StreetLine &&
      other.street == street &&
      other.shape == shape &&
      other.level == level;

  @override
  int get hashCode => Object.hash(street, shape, level);

  /// The shape is left out: its points would make the line unreadable in a
  /// failing test.
  @override
  String toString() => 'StreetLine(${street.value}, ${level.name})';
}

/// What a house dot shows (PLAN §5.3): the glyph and colour of a status.
enum HouseDotStatus {
  /// `○` à faire; a building with no door done.
  toDo,

  /// `●` fait; a building with every door done.
  done,

  /// `✗` personne.
  nobodyHome,

  /// `↻` repasser; a building with its own « repasser ».
  comeBack,

  /// `◐` a building with some doors done, not all.
  partial;

  /// The status of [house]'s dot: a single house shows its own status; a
  /// building shows its own « repasser » when it has one, otherwise how
  /// far its doors are.
  static HouseDotStatus of(House house) {
    final building = house.building;
    if (building == null) {
      return switch (house.status) {
        VisitStatus.toDo => toDo,
        VisitStatus.done => done,
        VisitStatus.nobodyHome => nobodyHome,
        VisitStatus.comeBack => comeBack,
      };
    }
    if (house.comeBack != null) return comeBack;
    return switch (building.status) {
      BuildingStatus.toDo => toDo,
      BuildingStatus.partial => partial,
      BuildingStatus.done => done,
    };
  }
}

/// A house shown on the map at its [position], with its [status]. A tap on
/// it names the [street] and the [number].
final class HouseDot {
  const HouseDot({
    required this.street,
    required this.number,
    required this.position,
    required this.status,
  });

  final StreetId street;
  final HouseNumber number;
  final GeoPoint position;
  final HouseDotStatus status;

  @override
  bool operator ==(Object other) =>
      other is HouseDot &&
      other.street == street &&
      other.number == number &&
      other.position == position &&
      other.status == status;

  @override
  int get hashCode => Object.hash(street, number, position, status);

  @override
  String toString() =>
      'HouseDot(${street.value}, ${number.label}, ${status.name})';
}
