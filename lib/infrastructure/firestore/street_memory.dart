import 'dart:async';

import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The streets of one campaign as this phone knows them: what the
/// Firestore listener gave last, with this phone's own changes taken the
/// moment they are made. Plain Dart, so its rules are tested without
/// Firestore.
///
/// It keeps the « memory first » promise of `StreetRepository`: a change
/// is [put] here before Firestore is even asked to write it, so the next
/// tap reads the street the previous one made. Firestore's own snapshot of
/// that write arrives a moment later and replaces it with the same
/// street.
///
/// One gap remains, a few milliseconds wide: a teammate's snapshot that
/// Firestore made just before this phone's write but delivers just after
/// it shows the street without that write, until the next snapshot. A tap
/// in that instant reads the older street.
final class StreetMemory {
  final _streets = <StreetId, Street>{};

  /// The streets whose writes the server has not received yet.
  var _unsent = <StreetId>{};

  /// Completes at the first answer of the listener (or its failure).
  final _loaded = Completer<void>();

  Object? _failure;
  StackTrace? _failureTrace;

  /// The ids of the streets each change touched. `sync: true` tells the
  /// listeners during the change itself, before anything else can run.
  final _changes = StreamController<Set<StreetId>>.broadcast(sync: true);

  /// Every street, once the listener has answered; throws what made it
  /// fail, if it did.
  Future<Map<StreetId, Street>> streets() async {
    await _loaded.future;
    if (_failure case final failure?) {
      Error.throwWithStackTrace(failure, _failureTrace!);
    }
    return _streets;
  }

  /// Takes [street] as changed on this phone.
  void put(Street street) {
    _streets[street.id] = street;
    _changes.add({street.id});
  }

  /// Takes what a snapshot of the listener says: each street of [changed]
  /// as it is now (null when it is gone or unreadable), and the [unsent]
  /// streets.
  void receive(Map<StreetId, Street?> changed, Set<StreetId> unsent) {
    for (final MapEntry(:key, :value) in changed.entries) {
      if (value == null) {
        _streets.remove(key);
      } else {
        _streets[key] = value;
      }
    }
    _unsent = unsent;
    if (!_loaded.isCompleted) _loaded.complete();
    _changes.add(changed.keys.toSet());
  }

  /// Takes the failure of the listener (this member may no longer read the
  /// tournée): every read and every observer gets it.
  void fail(Object error, StackTrace trace) {
    _failure = error;
    _failureTrace = trace;
    if (!_loaded.isCompleted) _loaded.complete();
    _changes.addError(error, trace);
  }

  /// [read] of the streets once loaded, then again after each change that
  /// [concerns] it.
  Stream<T> observe<T>(
    T Function(Map<StreetId, Street> streets) read,
    bool Function(Set<StreetId> changed) concerns,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<Set<StreetId>>? subscription;
    controller = StreamController<T>(
      onListen: () => unawaited(
        streets().then((streets) {
          // The listener may have left while waiting for the first answer.
          if (!controller.hasListener) return;
          controller.add(read(streets));
          subscription = _changes.stream
              .where(concerns)
              .listen(
                (_) => controller.add(read(streets)),
                onError: controller.addError,
              );
        }, onError: controller.addError),
      ),
      // A listener that leaves stops the updates and frees the stream.
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// The number of streets with writes waiting, now and each time it
  /// changes.
  Stream<int> watchUnsent() =>
      observe((_) => _unsent.length, (_) => true).distinct();
}
