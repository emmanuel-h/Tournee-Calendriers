import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// What a change of a street does to the open tournée's « maisons
/// visitées » (PLAN §5.13): a house or door made ✓ or ⊘ counts one more,
/// one taken back from ✓ or ⊘ one less, anything else nothing. So a ✓
/// undone, or changed to « À faire », does not count, and a ✓ turned into
/// ⊘ still counts once.
enum RoundVisit {
  /// A house or door became visited.
  visited,

  /// A house or door is no longer visited.
  unvisited,

  /// The count stays as it is.
  none;

  /// What [change] does to the count.
  ///
  /// Only the marks of the status picker, « De nouveau personne » and the
  /// undo of either move a status; every other change leaves the count.
  /// The `switch` names every change, so a new one must be placed here.
  static RoundVisit of(StreetChange change) => switch (change) {
    HouseMarked(:final before, :final status) => _between(
      before.status,
      status,
    ),
    DwellingMarked(:final before, :final status) => _between(
      before.status,
      status,
    ),
    HouseNobodyHomeAgain(:final before) => _between(
      before.status,
      VisitStatus.nobodyHome,
    ),
    DwellingNobodyHomeAgain(:final before) => _between(
      before.status,
      VisitStatus.nobodyHome,
    ),
    HouseReverted(:final replaced, :final house) => _between(
      replaced.status,
      house.status,
    ),
    DwellingReverted(:final replaced, :final dwelling) => _between(
      replaced.status,
      dwelling.status,
    ),
    ComeBackSet() ||
    DwellingComeBackSet() ||
    // A calendar more or less: the house is ✓ before and after.
    HouseCalendarsCounted() ||
    DwellingCalendarsCounted() ||
    BuildingLaidOut() ||
    BuildingRemoved() ||
    NumberRenamed() ||
    StreetDeleted() ||
    StreetRestored() ||
    StreetShapeFilled() ||
    StreetPartChanged() ||
    NumbersAdded() ||
    NumberRemoved() ||
    NumberRestored() ||
    NumbersPurged() ||
    StreetRenamed() => none,
  };

  /// What undoing a change that did this does.
  RoundVisit get undone => switch (this) {
    visited => unvisited,
    unvisited => visited,
    none => none,
  };

  static RoundVisit _between(VisitStatus before, VisitStatus after) =>
      switch ((_isVisited(before), _isVisited(after))) {
        (false, true) => visited,
        (true, false) => unvisited,
        _ => none,
      };

  /// ✓ and ⊘: the statuses `Progress.visited` counts.
  static bool _isVisited(VisitStatus status) => switch (status) {
    VisitStatus.done || VisitStatus.refused => true,
    VisitStatus.toDo || VisitStatus.nobodyHome || VisitStatus.comeBack => false,
  };
}
