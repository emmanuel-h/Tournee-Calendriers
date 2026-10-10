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

  /// The `ref` of the build the change was made in. Riverpod keeps the
  /// notifier when it builds again, which happens when the street storage
  /// is replaced (another tournée opened), and gives that build a new
  /// `ref`: the old one is then no longer `mounted`.
  Ref? _keptIn;

  /// Keeps [change] for « Annuler », in place of the one kept before.
  void keepForUndo(StreetChange change) {
    _lastChange = change;
    _keptIn = ref;
  }

  /// Puts back what the last change replaced, once. Should that be
  /// impossible (what it touched was removed since), nothing happens: the
  /// screen shows the street as it is. A change made in another tournée
  /// than the open one is not undone: the same street (moved from the
  /// phone, same id) may be in both.
  Future<void> undo() async {
    final change = _lastChange;
    if (change == null) return;
    _lastChange = null;
    if (!_keptIn!.mounted) return;
    await ref.read(undoLastChangeProvider)(change);
  }
}
