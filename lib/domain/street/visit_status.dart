/// Whether a house (or a dwelling) has been visited during the campaign
/// (PLAN §2): « à faire », « fait » or « personne ».
///
/// The app records only whether the door was visited, never what the
/// residents answered (PLAN §13, Q3).
enum VisitStatus {
  /// « À faire »: not visited yet.
  toDo,

  /// « Fait »: the calendar was handed over.
  done,

  /// « Personne »: nobody answered the door.
  nobodyHome;

  /// The status a tap on the tile moves to: `toDo → done → nobodyHome → toDo`
  /// (PLAN §5.6).
  VisitStatus get next => switch (this) {
    toDo => done,
    done => nobodyHome,
    nobodyHome => toDo,
  };
}
