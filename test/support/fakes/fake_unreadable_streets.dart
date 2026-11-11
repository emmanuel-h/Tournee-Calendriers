// UnreadableStreets in memory: the test says which streets cannot be read,
// and sees which ones were deleted.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/unreadable_streets.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';

final class FakeUnreadableStreets implements UnreadableStreets {
  /// [unreadable] streets at first (none by default).
  FakeUnreadableStreets([List<UnreadableStreet> unreadable = const []])
    : _unreadable = [...unreadable];

  final List<UnreadableStreet> _unreadable;

  /// The ids passed to [delete], in order.
  final deleted = <StreetId>[];

  final _changes = StreamController<void>.broadcast(sync: true);

  /// Now [unreadable] cannot be read (a teammate's write broke it).
  void add(UnreadableStreet unreadable) {
    _unreadable.add(unreadable);
    _changes.add(null);
  }

  /// The list can no longer be read (the member left the secteur).
  void fail(Object error) => _changes.addError(error);

  @override
  Stream<List<UnreadableStreet>> watchUnreadable() {
    late final StreamController<List<UnreadableStreet>> controller;
    StreamSubscription<void>? changes;
    void emit() => controller.add(List.unmodifiable(_unreadable));
    controller = StreamController(
      onListen: () {
        emit();
        changes = _changes.stream.listen(
          (_) => emit(),
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

  @override
  Future<void> delete(StreetId id) async {
    deleted.add(id);
    _unreadable.removeWhere((street) => street.id == id);
    _changes.add(null);
  }
}
