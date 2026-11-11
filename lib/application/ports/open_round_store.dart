import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';

/// Where the phone keeps its tournées (PLAN §6.3, `open_round.json`): the
/// tournée on, and the validated ones the server does not have yet
/// ([UnsentRound], PLAN §5.16). On the phone only, written at each change,
/// so a tournée survives a kill and runs offline, cold start included
/// (PLAN §7). Its dons never leave the phone: only the summary does, once
/// validated (`RoundLedger`).
///
/// An application port: an adapter of `infrastructure/local_storage/`
/// implements it, tests use a fake.
///
/// Read without waiting: the adapter loads the tournées before the first
/// screen (the composition root does it at start-up), so Accueil shows
/// « En tournée » from the first frame.
abstract interface class OpenRoundStore {
  /// The tournée on, as last saved; null when none is.
  Round? get openRound;

  /// Each tournée saved from now on, and null once it is [clear]ed or
  /// validated ([keepValidated]). Nothing is given on listening: read
  /// [openRound] for the one now.
  Stream<Round?> get changes;

  /// The validated tournées not yet with their secteur, in the order they
  /// were validated.
  List<UnsentRound> get unsent;

  /// [unsent] after each change of it, from now on. Nothing is given on
  /// listening.
  Stream<List<UnsentRound>> get unsentChanges;

  /// Whether the phone's file of tournées could not be read at start-up:
  /// the phone then started with none, and the user is told (#143).
  bool get unreadableAtStart;

  /// Keeps [round] as the tournée on. [openRound] and [changes] give it at
  /// once; the returned `Future` ends once it is kept on the phone.
  Future<void> save(Round round);

  /// Forgets the tournée on, its dons with it.
  Future<void> clear();

  /// « Valider la tournée »: the tournée on is no longer on, and
  /// [validated] waits among [unsent], in **one** write, so a kill never
  /// leaves both or neither. One with the same id is replaced.
  Future<void> keepValidated(UnsentRound validated);

  /// Puts [round] in place of the unsent tournée of the same id (refused,
  /// or waiting again). Nothing happens when none has that id any more
  /// (forgotten meanwhile): a late answer never brings one back.
  Future<void> updateUnsent(UnsentRound round);

  /// Forgets the unsent tournée [id]: the server has it, or « Effacer ».
  /// Nothing happens when none has that id.
  Future<void> forgetUnsent(RoundId id);
}
