// An in-memory SectorRepository for the use-case, presentation and widget
// tests: no Firestore, every call answers at once. It records what the use
// cases stored so tests can assert the exact tournée and change.
import 'dart:async';

import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

final class FakeSectorRepository implements SectorRepository {
  /// A repository already holding [sectors].
  FakeSectorRepository([Iterable<Sector> sectors = const []]) {
    for (final sector in sectors) {
      _sectors[sector.id] = sector;
    }
  }

  final _sectors = <SectorId, Sector>{};

  /// Fires after each change. `sync: true` delivers it during the change
  /// itself, so a test sees the new value without waiting a turn.
  final _changed = StreamController<void>.broadcast(sync: true);

  /// Every (tournée, change) given to [save], in order.
  final saved = <(Sector, SectorChange)>[];

  /// Every deletion given to [delete], in order.
  final deleted = <SectorDeleted>[];

  /// Plays a phone without network for what needs the server (a new code,
  /// an admin joining, deleting): those fail with `noNetwork` and store
  /// nothing.
  var offline = false;

  /// Plays a server that no longer takes the phone for an admin's (its
  /// `admins/{uid}` removed): what only an admin does on the server (a new
  /// code, an admin joining, deleting) fails with `notAdmin` and stores
  /// nothing.
  var notAdmin = false;

  /// When set, a new code is stored as this one instead of the code drawn,
  /// as the server does when another tournée holds the drawn one.
  JoinCode? codeTaken;

  /// When set, [watch] fails with it instead of giving the tournée.
  Object? watchError;

  /// When true, [watch] gives nothing at all, as Firestore before its
  /// first answer: what follows it stays loading.
  bool watchSilent = false;

  /// When set, [find] fails with it instead of giving the tournée.
  Error? findError;

  /// When set, [add] stores nothing and fails with it, as the server does
  /// for a number taken or a phone without network.
  AddSectorFailure? addFailure;

  /// When set, [add] stores the tournée with this code instead of the one
  /// drawn, as the server does when another tournée holds the drawn one.
  JoinCode? addCodeTaken;

  /// Every tournée given to [add], in order.
  final added = <Sector>[];

  /// The tournée [id] as stored now.
  Sector? operator [](SectorId id) => _sectors[id];

  /// Stores [sector] as a teammate's phone would (a request arrives, a
  /// teammate accepts it): the listeners hear it.
  void put(Sector sector) {
    _sectors[sector.id] = sector;
    _changed.add(null);
  }

  /// The tournée [id] can no longer be read (this member was removed).
  void lose(SectorId id) {
    _sectors.remove(id);
    _changed.add(null);
  }

  @override
  Future<Sector?> find(SectorId id) async {
    if (findError case final error?) throw error;
    return _sectors[id];
  }

  /// Every tournée [watch] was asked for, in order.
  final watched = <SectorId>[];

  /// How many listen to each tournée now.
  final _listeners = <SectorId, int>{};

  /// Whether someone still listens to the tournée [id].
  bool isWatching(SectorId id) => (_listeners[id] ?? 0) > 0;

  @override
  Stream<Sector?> watch(SectorId id) {
    watched.add(id);
    late final StreamController<Sector?> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<Sector?>(
      onListen: () {
        _listeners[id] = (_listeners[id] ?? 0) + 1;
        if (watchError case final error?) {
          controller.addError(error);
          return;
        }
        if (watchSilent) return;
        controller.add(_sectors[id]);
        subscription = _changed.stream.listen(
          (_) => controller.add(_sectors[id]),
        );
      },
      // A listener that leaves stops the updates and frees the stream.
      onCancel: () async {
        _listeners[id] = _listeners[id]! - 1;
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Result<Sector, AddSectorFailure>> add(Sector sector) async {
    added.add(sector);
    if (addFailure case final failure?) return Err(failure);
    final stored = switch (addCodeTaken) {
      final code? => _withCode(sector, code),
      null => sector,
    };
    put(stored);
    return Ok(stored);
  }

  static Sector _withCode(Sector sector, JoinCode code) =>
      switch (Sector.create(
        id: sector.id,
        number: sector.number,
        centre: sector.centre,
        joinCode: code,
        createdBy: sector.createdBy,
        createdAt: sector.createdAt,
        currentCampaign: sector.currentCampaign,
        members: sector.members,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('$failure'),
      };

  @override
  Future<Result<Sector, SectorWriteFailure>> save(
    Sector sector,
    SectorChange change,
  ) async {
    var stored = sector;
    if (change is AdminJoined || change is JoinCodeRegenerated) {
      if (offline) return const Err(SectorWriteFailure.noNetwork);
      if (notAdmin) return const Err(SectorWriteFailure.notAdmin);
    }
    if (change is JoinCodeRegenerated) {
      if (codeTaken case final code?) stored = _withCode(sector, code);
    }
    saved.add((sector, change));
    put(stored);
    return Ok(stored);
  }

  @override
  Future<Result<SectorDeleted, SectorWriteFailure>> delete(
    SectorDeleted deletion,
  ) async {
    if (offline) return const Err(SectorWriteFailure.noNetwork);
    if (notAdmin) return const Err(SectorWriteFailure.notAdmin);
    deleted.add(deletion);
    lose(deletion.sector.id);
    return Ok(deletion);
  }
}
