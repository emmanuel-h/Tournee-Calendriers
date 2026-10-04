import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// « Annuler » of the snackbar (PLAN §5.6): puts back exactly what the last
/// change replaced, the whole house or door as it was (PLAN §7: a normal
/// write of the previous value, not a rollback). Needs no network.
///
/// The screen keeps the change the last use case returned and passes it
/// here; the use case keeps nothing itself, so there is no hidden state to
/// get out of step with the screen.
final class UndoLastChange {
  const UndoLastChange(this._streets);

  final StreetRepository _streets;

  /// Undoes [change] on its street, saves the undo and returns the change it
  /// made (which could be undone in turn).
  Future<Result<StreetChange, CommandFailure<UndoFailure>>> call(
    StreetChange change,
  ) => runOnStreet(_streets, change.streetId, (street) => street.undo(change));
}
