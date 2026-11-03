/// Whether a house (or a dwelling) has been visited during the campaign
/// (PLAN §2): « à faire », « fait », « refusé », « personne » or
/// « repasser », chosen in the status picker (PLAN §5.6).
///
/// A door has exactly one of them: it is never « personne » and
/// « repasser » at once. The app records only whether the door was visited,
/// never what the residents answered (PLAN §13, Q3).
enum VisitStatus {
  /// « À faire »: not visited yet.
  toDo,

  /// « Fait »: the calendar was handed over.
  done,

  /// « Refusé »: the residents did not want a calendar (#113). Visited, so
  /// it counts with [done] in the street's progress (`Progress.visited`);
  /// never tried again, so it has no tries and no `ComeBack`.
  refused,

  /// « Personne »: nobody answered the door.
  nobodyHome,

  /// « Repasser »: the residents asked the team to come back later. Only a
  /// door with this status carries a `ComeBack` (when to come back, if
  /// set: « samedi vers 18 h »).
  comeBack,
}
