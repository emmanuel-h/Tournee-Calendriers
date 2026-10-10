// An in-memory TourneeRepository for the use-case, presentation and widget
// tests: no Firestore, every call answers at once. It records what the use
// cases stored so tests can assert the exact tournée and change.
import 'dart:async';

import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';

final class FakeTourneeRepository implements TourneeRepository {
  /// A repository already holding [tournees].
  FakeTourneeRepository([Iterable<Tournee> tournees = const []]) {
    for (final tournee in tournees) {
      _tournees[tournee.id] = tournee;
    }
  }

  final _tournees = <TourneeId, Tournee>{};

  /// Fires after each change. `sync: true` delivers it during the change
  /// itself, so a test sees the new value without waiting a turn.
  final _changed = StreamController<void>.broadcast(sync: true);

  /// Every (tournée, change) given to [save], in order.
  final saved = <(Tournee, TourneeChange)>[];

  /// Every deletion given to [delete], in order.
  final deleted = <TourneeDeleted>[];

  /// Plays a phone without network for what needs the server (a new code,
  /// deleting): those fail with `noNetwork` and store nothing.
  var offline = false;

  /// When set, a new code is stored as this one instead of the code drawn,
  /// as the server does when another tournée holds the drawn one.
  JoinCode? codeTaken;

  /// When set, [watch] fails with it instead of giving the tournée.
  Object? watchError;

  /// The tournée [id] as stored now.
  Tournee? operator [](TourneeId id) => _tournees[id];

  /// Stores [tournee] as a teammate's phone would (a request arrives, a
  /// teammate accepts it): the listeners hear it.
  void put(Tournee tournee) {
    _tournees[tournee.id] = tournee;
    _changed.add(null);
  }

  /// The tournée [id] can no longer be read (this member was removed).
  void lose(TourneeId id) {
    _tournees.remove(id);
    _changed.add(null);
  }

  @override
  Future<Tournee?> find(TourneeId id) async => _tournees[id];

  @override
  Stream<Tournee?> watch(TourneeId id) {
    late final StreamController<Tournee?> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<Tournee?>(
      onListen: () {
        if (watchError case final error?) {
          controller.addError(error);
          return;
        }
        controller.add(_tournees[id]);
        subscription = _changed.stream.listen(
          (_) => controller.add(_tournees[id]),
        );
      },
      // A listener that leaves stops the updates and frees the stream.
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Result<Tournee, AddTourneeFailure>> add(Tournee tournee) async {
    put(tournee);
    return Ok(tournee);
  }

  @override
  Future<Result<Tournee, TourneeWriteFailure>> save(
    Tournee tournee,
    TourneeChange change,
  ) async {
    var stored = tournee;
    if (change is JoinCodeRegenerated) {
      if (offline) return const Err(TourneeWriteFailure.noNetwork);
      if (codeTaken case final code?) {
        stored = switch (Tournee.create(
          id: tournee.id,
          number: tournee.number,
          centre: tournee.centre,
          joinCode: code,
          createdBy: tournee.createdBy,
          createdAt: tournee.createdAt,
          currentCampaign: tournee.currentCampaign,
          members: tournee.members,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError('$failure'),
        };
      }
    }
    saved.add((tournee, change));
    put(stored);
    return Ok(stored);
  }

  @override
  Future<Result<TourneeDeleted, TourneeWriteFailure>> delete(
    TourneeDeleted deletion,
  ) async {
    if (offline) return const Err(TourneeWriteFailure.noNetwork);
    deleted.add(deletion);
    lose(deletion.tournee.id);
    return Ok(deletion);
  }
}
