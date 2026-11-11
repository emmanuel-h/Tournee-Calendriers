// An in-memory OpenRoundStore: no file, answers at once, and records every
// save so tests can assert it.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/application/use_cases/round_visits.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';

import 'fake_my_sectors_store.dart';

final class FakeOpenRoundStore implements OpenRoundStore {
  /// A phone where [openRound] is on (none by default), and [unsent] wait.
  FakeOpenRoundStore([this.openRound, List<UnsentRound> unsent = const []])
    : unsent = List.unmodifiable(unsent);

  @override
  Round? openRound;

  @override
  List<UnsentRound> unsent;

  @override
  bool unreadableAtStart = false;

  /// Every tournée given to [save], in order.
  final saves = <Round>[];

  /// How many times [clear] was called.
  var clears = 0;

  // `sync: true`: a listener hears a save before `save` returns, as the
  // real adapter's listeners do on the same turn of the event loop.
  final _changes = StreamController<Round?>.broadcast(sync: true);
  final _unsentChanges = StreamController<List<UnsentRound>>.broadcast(
    sync: true,
  );

  @override
  Stream<Round?> get changes => _changes.stream;

  @override
  Stream<List<UnsentRound>> get unsentChanges => _unsentChanges.stream;

  @override
  Future<void> save(Round round) async {
    saves.add(round);
    openRound = round;
    _changes.add(round);
  }

  @override
  Future<void> clear() async {
    clears++;
    openRound = null;
    _changes.add(null);
  }

  @override
  Future<void> keepValidated(UnsentRound validated) async {
    openRound = null;
    _changes.add(null);
    _setUnsent([
      for (final round in unsent)
        if (round.id != validated.id) round,
      validated,
    ]);
  }

  @override
  Future<void> updateUnsent(UnsentRound round) async {
    if (!unsent.any((kept) => kept.id == round.id)) return;
    _setUnsent([for (final kept in unsent) kept.id == round.id ? round : kept]);
  }

  @override
  Future<void> forgetUnsent(RoundId id) async {
    if (!unsent.any((kept) => kept.id == id)) return;
    _setUnsent([
      for (final kept in unsent)
        if (kept.id != id) kept,
    ]);
  }

  void _setUnsent(List<UnsentRound> rounds) {
    unsent = List.unmodifiable(rounds);
    _unsentChanges.add(unsent);
  }
}

/// The tournée step of the status use cases on a phone with no tournée
/// on, for the tests of marks that count nothing.
RoundVisits noRoundOn() =>
    RoundVisits(FakeOpenRoundStore(), FakeMySectorsStore());
