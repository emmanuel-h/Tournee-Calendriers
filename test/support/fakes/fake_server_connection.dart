// A ServerConnection driven by the test: it says whether the phone
// reaches the server, as the metadata of Firestore's snapshots would.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/server_connection.dart';

final class FakeServerConnection implements ServerConnection {
  /// Offline at first when [offline] says so (online by default).
  // `this._offline` as a named parameter: callers write `offline:`.
  FakeServerConnection({this._offline = false});

  bool _offline;

  final _changes = StreamController<bool>.broadcast(sync: true);

  /// Whether someone still follows it.
  bool get isFollowed => _changes.hasListener;

  /// The phone now reaches the server, or not.
  void reach({required bool offline}) {
    _offline = offline;
    _changes.add(offline);
  }

  /// It can no longer be told (the member left the tournée).
  void fail(Object error) => _changes.addError(error);

  /// Whether offline now, then each change, like the real adapter.
  @override
  Stream<bool> watchOffline() {
    late final StreamController<bool> controller;
    StreamSubscription<bool>? changes;
    controller = StreamController<bool>(
      onListen: () {
        controller.add(_offline);
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
