/// Whether a house (or a dwelling) has been visited during the campaign
/// (PLAN §2): « à faire », « fait », « personne » or « repasser ».
///
/// A door has exactly one of them: it is never « personne » and
/// « repasser » at once. The app records only whether the door was visited,
/// never what the residents answered (PLAN §13, Q3).
enum VisitStatus {
  /// « À faire »: not visited yet.
  toDo,

  /// « Fait »: the calendar was handed over.
  done,

  /// « Personne »: nobody answered the door.
  nobodyHome,

  /// « Repasser »: the residents asked the team to come back later. Only a
  /// door with this status carries a `ComeBack` (its optional hint, « après
  /// 19h »).
  comeBack;

  /// The status a tap on the tile moves to:
  /// `toDo → done → nobodyHome → comeBack → toDo` (PLAN §5.6).
  VisitStatus get next => switch (this) {
    toDo => done,
    done => nobodyHome,
    nobodyHome => comeBack,
    comeBack => toDo,
  };
}
