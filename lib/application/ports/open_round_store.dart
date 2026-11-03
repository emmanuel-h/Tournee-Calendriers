import 'package:tournee_calendriers/domain/round/round.dart';

/// Where the phone keeps the tournée on (PLAN §6.3, `open_round.json`): on
/// the phone only, written at each change, so a tournée survives a kill
/// and runs offline, cold start included (PLAN §7). Its dons never leave
/// the phone: only the summary does, once validated (`RoundLedger`).
///
/// An application port: an adapter of `infrastructure/local_storage/`
/// implements it, tests use a fake.
///
/// Read without waiting: the adapter loads the tournée before the first
/// screen (the composition root does it at start-up), so Accueil shows
/// « En tournée » from the first frame.
abstract interface class OpenRoundStore {
  /// The tournée on, as last saved; null when none is.
  Round? get openRound;

  /// Each tournée saved from now on, and null once it is [clear]ed.
  /// Nothing is given on listening: read [openRound] for the one now.
  Stream<Round?> get changes;

  /// Keeps [round] as the tournée on. [openRound] and [changes] give it at
  /// once; the returned `Future` ends once it is kept on the phone.
  Future<void> save(Round round);

  /// Forgets the tournée on, its dons with it.
  Future<void> clear();
}
