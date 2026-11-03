import 'package:tournee_calendriers/domain/street/progress.dart';

/// Where a building stands, shown on its tile in the street (PLAN §5.7):
/// derived from its doors every time, never stored or set by hand.
enum BuildingStatus {
  /// No door is visited yet: doors where nobody was home, or to come back
  /// to, count as not visited.
  toDo,

  /// Some doors are visited, not all: the tile shows `◐ visited/total`.
  partial,

  /// Every door is visited: done or refused (`Progress.visited`), as a
  /// street is « faite » on the map (PLAN §5.6).
  done;

  /// The status of a building whose doors add up to [progress]. A building
  /// without any door (never the case in a `Building`) counts as to do.
  static BuildingStatus of(Progress progress) {
    if (progress.visited == 0) return toDo;
    if (progress.visited == progress.total) return done;
    return partial;
  }
}
