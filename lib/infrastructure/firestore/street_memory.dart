import 'dart:async';

import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';
import 'package:tournee_calendriers/infrastructure/shared/load_then_follow.dart';

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

  /// The streets whose document cannot be read (#149), apart: a street is
  /// in [_streets] or here, never in both.
  final _unreadable = <StreetId, UnreadableStreet>{};

  /// The streets whose writes the server has not received yet.
  var _unsent = <StreetId>{};

  /// Whether the last snapshot came from the phone's copy only.
  var _fromCache = false;

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

  /// Forgets the street [id], deleted on this phone: the 30-day purge of
  /// the Corbeille, or an unreadable street an admin deletes.
  void remove(StreetId id) {
    _streets.remove(id);
    _unreadable.remove(id);
    _changes.add({id});
  }

  /// Takes what a snapshot of the listener says: each street of [changed]
  /// as it is now (null when it is gone), the streets it could not read
  /// ([unreadable]), the [unsent] streets, and whether it came [fromCache]
  /// (the server out of reach).
  void receive(
    Map<StreetId, Street?> changed,
    Set<StreetId> unsent, {
    bool fromCache = false,
    Map<StreetId, UnreadableStreet> unreadable = const {},
  }) {
    for (final MapEntry(:key, :value) in changed.entries) {
      // Read, or gone: no longer unreadable either way.
      _unreadable.remove(key);
      if (value == null) {
        _streets.remove(key);
      } else {
        _streets[key] = value;
      }
    }
    for (final MapEntry(:key, :value) in unreadable.entries) {
      _streets.remove(key);
      _unreadable[key] = value;
    }
    _unsent = unsent;
    _fromCache = fromCache;
    if (!_loaded.isCompleted) _loaded.complete();
    _changes.add({...changed.keys, ...unreadable.keys});
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
  ) => loadThenFollow(
    load: streets,
    changes: _changes.stream,
    concerns: concerns,
    read: read,
  );

  /// The streets whose document cannot be read, now and each time they
  /// change; a mark on another street gives nothing.
  Stream<List<UnreadableStreet>> watchUnreadable() => observe(
    (_) => List<UnreadableStreet>.unmodifiable(_unreadable.values),
    (_) => true,
  ).distinct(sameItems);

  /// The number of streets with writes waiting, now and each time it
  /// changes.
  Stream<int> watchUnsent() =>
      observe((_) => _unsent.length, (_) => true).distinct();

  /// Whether the listener answers from the phone's copy only (offline),
  /// now and each time it changes.
  Stream<bool> watchOffline() =>
      observe((_) => _fromCache, (_) => true).distinct();
}
