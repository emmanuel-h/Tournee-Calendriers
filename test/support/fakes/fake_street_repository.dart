// An in-memory StreetRepository for the use-case and presentation tests:
// no file, no network, every call answers at once. It records what the use
// cases stored so tests can assert the exact street and change.
import 'dart:async';

import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

final class FakeStreetRepository implements StreetRepository {
  /// A repository already holding [streets].
  FakeStreetRepository([Iterable<Street> streets = const []]) {
    for (final street in streets) {
      _streets[street.id] = street;
    }
  }

  final _streets = <StreetId, Street>{};

  /// Fires after each write. `sync: true` delivers the event during the
  /// write itself, so a test sees the new value without waiting a turn.
  final _changed = StreamController<void>.broadcast(sync: true);

  /// Every street given to [add], in order.
  final added = <Street>[];

  /// Every (street, change) given to [save], in order.
  final saved = <(Street, StreetChange)>[];

  /// When set, the next [save] stores nothing and throws it, as a full
  /// disk would; the saves after it work again.
  Exception? failNextSave;

  /// The street [id] as stored now.
  Street? operator [](StreetId id) => _streets[id];

  @override
  Future<Street?> find(StreetId id) async => _streets[id];

  @override
  Future<Street?> findByBanId(BanStreetId banId) async {
    for (final street in _streets.values) {
      if (street.banId == banId) return street;
    }
    return null;
  }

  @override
  Stream<Street?> watch(StreetId id) => _observe(() => _streets[id]);

  @override
  Stream<List<Street>> watchAll() => _observe(
    () => [
      for (final street in _streets.values)
        if (!street.isDeleted) street,
    ],
  );

  @override
  Future<void> add(Street street) async {
    added.add(street);
    _streets[street.id] = street;
    _changed.add(null);
  }

  @override
  Future<void> save(Street street, StreetChange change) async {
    if (failNextSave case final error?) {
      failNextSave = null;
      throw error;
    }
    saved.add((street, change));
    _streets[street.id] = street;
    _changed.add(null);
  }

  /// A stream that gives [read] now, then again after each write.
  Stream<T> _observe<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changed.stream.listen((_) => controller.add(read()));
      },
      // A listener that leaves stops the updates and frees the stream.
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}
