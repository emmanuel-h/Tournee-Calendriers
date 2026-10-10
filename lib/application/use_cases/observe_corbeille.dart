import 'dart:async';

import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The Corbeille (PLAN §5.11): the deleted streets and the numbers removed
/// from the others, the latest first (see `corbeilleOf`), now and after
/// each change to any street. Works offline: it reads what the phone holds.
///
/// « Restaurer » goes through `EditStreetNumbers` (`RestoreStreet`,
/// `RestoreNumber`), like the other changes of a street.
final class ObserveCorbeille {
  const ObserveCorbeille(this._streets);

  final StreetRepository _streets;

  /// Follows the streets shown and the deleted ones (the repository gives
  /// them apart) and gives a new Corbeille each time either changes, once
  /// both have answered.
  Stream<List<CorbeilleItem>> call() {
    // A `StreamController` makes a stream by hand: it starts the two
    // listeners when someone listens, and stops them when they leave.
    late final StreamController<List<CorbeilleItem>> controller;
    StreamSubscription<List<Street>>? shownListener;
    StreamSubscription<List<Street>>? deletedListener;
    List<Street>? shown;
    List<Street>? deleted;

    void emit() {
      // Local copies: Dart does not promote a variable a closure captures.
      final (streets, inCorbeille) = (shown, deleted);
      if (streets == null || inCorbeille == null) return;
      controller.add(corbeilleOf([...inCorbeille, ...streets]));
    }

    controller = StreamController<List<CorbeilleItem>>(
      onListen: () {
        shownListener = _streets.watchAll().listen((streets) {
          shown = streets;
          emit();
        }, onError: controller.addError);
        deletedListener = _streets.watchDeleted().listen((streets) {
          deleted = streets;
          emit();
        }, onError: controller.addError);
      },
      // Nobody listens any more: stop both listeners and free the stream.
      onCancel: () async {
        await shownListener?.cancel();
        await deletedListener?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}
