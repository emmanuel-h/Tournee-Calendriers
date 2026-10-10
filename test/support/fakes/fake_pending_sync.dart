// A PendingSync driven by the test: it says how many streets wait to be
// sent, as Firestore's snapshot metadata would.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/pending_sync.dart';

final class FakePendingSync implements PendingSync {
  /// [unsent] streets waiting to be sent at first (none by default).
  FakePendingSync([this._unsent = 0]);

  int _unsent;

  final _changes = StreamController<int>.broadcast(sync: true);

  /// Whether someone still follows the count.
  bool get isFollowed => _changes.hasListener;

  /// Now [streets] streets wait to be sent.
  void unsent(int streets) {
    _unsent = streets;
    _changes.add(streets);
  }

  /// The count can no longer be read (the member left the tournée).
  void fail(Object error) => _changes.addError(error);

  /// The count now, then each new one, like the real adapter.
  @override
  Stream<int> watchUnsentStreets() {
    late final StreamController<int> controller;
    StreamSubscription<int>? changes;
    controller = StreamController<int>(
      onListen: () {
        controller.add(_unsent);
        changes = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await changes?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}
