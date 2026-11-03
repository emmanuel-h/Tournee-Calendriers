import 'package:tournee_calendriers/domain/street/progress.dart';

/// How a street of the secteur is coloured on the map (PLAN §5.3, §5.14),
/// from its progress. The legend reads « faite », « en partie », « à
/// faire ».
enum ProgressLevel {
  /// « À faire »: no door visited yet.
  toDo,

  /// « En partie »: some doors marked, not all visited (doors where nobody
  /// was home, or to come back to, are still to visit).
  partial,

  /// « Fait »: every door visited (done or refused, `Progress.visited`),
  /// nothing to come back to. A refusal finishes a door as a calendar
  /// does: nobody goes back to it.
  done;

  /// The level of a street with [progress]. A street without any door is
  /// never finished.
  static ProgressLevel of(Progress progress) {
    final finished =
        progress.total > 0 &&
        progress.visited == progress.total &&
        progress.toComeBack == 0;
    if (finished) return done;
    if (progress.toDo == progress.total) return toDo;
    return partial;
  }
}
