import 'package:tournee_calendriers/domain/street/progress.dart';

/// Where a building stands, shown on its tile in the street (PLAN §5.7):
/// derived from its doors every time, never stored or set by hand.
enum BuildingStatus {
  /// No door is done yet (doors where nobody was home count as not done).
  toDo,

  /// Some doors are done, not all: the tile shows `◐ done/total`.
  partial,

  /// Every door is done.
  done;

  /// The status of a building whose doors add up to [progress]. A building
  /// without any door (never the case in a `Building`) counts as to do.
  static BuildingStatus of(Progress progress) {
    if (progress.done == 0) return toDo;
    if (progress.done == progress.total) return done;
    return partial;
  }
}
