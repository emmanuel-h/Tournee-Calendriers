import 'package:tournee_calendriers/domain/street/progress.dart';

/// How a street of the tournée is coloured on the map (PLAN §5.3), from its
/// progress and whether someone took it. The legend reads « fait », « en
/// partie », « à faire », « libre ».
enum ProgressLevel {
  /// « Libre »: nobody took the street and it is not finished; someone can
  /// take it.
  free,

  /// « À faire »: someone took it; no door visited yet.
  toDo,

  /// « En partie »: some doors visited, not all done (doors where nobody
  /// was home, or to come back to, are visited but not done).
  partial,

  /// « Fait »: every door done, nothing to come back to.
  done;

  /// The level of a street with [progress], [taken] when at least one
  /// member has it in « Mes rues ».
  ///
  /// A finished street is « fait » whether or not someone still holds it:
  /// nobody needs to take it again. A street without any door is never
  /// finished.
  static ProgressLevel of(Progress progress, {required bool taken}) {
    final finished =
        progress.total > 0 &&
        progress.done == progress.total &&
        progress.toComeBack == 0;
    if (finished) return done;
    if (!taken) return free;
    if (progress.toDo == progress.total) return toDo;
    return partial;
  }
}
