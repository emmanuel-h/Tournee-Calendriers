import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// « Annuler » of the snackbar, for a notifier whose changes can be undone:
/// it keeps the last change it made ([keepForUndo]) and [undo] puts back
/// what that change replaced (`UndoLastChange`).
///
/// Only the last change can be undone (PLAN §5.6), and only once. The
/// notifier is `autoDispose`, so the change is forgotten with the screen.
mixin UndoesLastChange<S> on Notifier<S> {
  StreetChange? _lastChange;

  /// Keeps [change] for « Annuler », in place of the one kept before.
  void keepForUndo(StreetChange change) => _lastChange = change;

  /// Puts back what the last change replaced, once. Should that be
  /// impossible (what it touched was removed since), nothing happens: the
  /// screen shows the street as it is.
  Future<void> undo() async {
    final change = _lastChange;
    if (change == null) return;
    _lastChange = null;
    await ref.read(undoLastChangeProvider)(change);
  }
}
