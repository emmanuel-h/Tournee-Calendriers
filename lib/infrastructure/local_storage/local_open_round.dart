import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/open_round_json_mapper.dart';

/// The [OpenRoundStore] of the phone: `open_round.json` in the storage
/// folder (PLAN §6.3), read once at start-up, then answered from memory and
/// written again whole at each change. The tournée on and those validated
/// but not yet sent share the file, so validating one is a single write.
/// No network, ever: a tournée survives a kill and an offline cold start.
final class LocalOpenRound implements OpenRoundStore {
  LocalOpenRound._(
    this._file,
    this.openRound,
    List<UnsentRound> unsent, {
    required this.unreadableAtStart,
  }) : unsent = List.unmodifiable(unsent);

  /// Reads the tournées kept in [file]. A missing file means none. An
  /// unreadable one means none too, and [unreadableAtStart] says so, for
  /// the user to be told (#143); the file is left as it is until the next
  /// change.
  static Future<LocalOpenRound> load(File file) async {
    final stored = JsonFile(file);
    try {
      final read = await stored.read();
      final rounds = read == null ? null : roundsFromJson(read);
      return LocalOpenRound._(
        stored,
        rounds?.open,
        rounds?.unsent ?? const [],
        unreadableAtStart: false,
      );
    } on FormatException {
      // Not JSON, or not our schema.
      return LocalOpenRound._(stored, null, const [], unreadableAtStart: true);
    }
  }

  final JsonFile _file;

  // `broadcast`: Accueil's band, the street screen and Collecte may listen
  // at once.
  final _changes = StreamController<Round?>.broadcast();
  final _unsentChanges = StreamController<List<UnsentRound>>.broadcast();

  @override
  Round? openRound;

  @override
  List<UnsentRound> unsent;

  @override
  final bool unreadableAtStart;

  @override
  Stream<Round?> get changes => _changes.stream;

  @override
  Stream<List<UnsentRound>> get unsentChanges => _unsentChanges.stream;

  @override
  Future<void> save(Round round) => _keep(open: round);

  @override
  Future<void> clear() => _keep(open: null);

  @override
  Future<void> keepValidated(UnsentRound validated) =>
      _keep(open: null, unsent: [..._without(validated.id), validated]);

  @override
  Future<void> updateUnsent(UnsentRound round) async {
    if (!_holds(round.id)) return;
    await _keep(
      open: openRound,
      unsent: [for (final kept in unsent) kept.id == round.id ? round : kept],
    );
  }

  @override
  Future<void> forgetUnsent(RoundId id) async {
    if (!_holds(id)) return;
    await _keep(open: openRound, unsent: _without(id));
  }

  bool _holds(RoundId id) => unsent.any((round) => round.id == id);

  List<UnsentRound> _without(RoundId id) => [
    for (final round in unsent)
      if (round.id != id) round,
  ];

  /// Answers [open] and [unsent] at once, then writes them (queued after
  /// the writes already asked, so two quick dons reach the disk in order).
  ///
  /// [unsent] null leaves the unsent tournées as they are: a save or clear
  /// of the tournée on, always told to [changes]. Given, they are told to
  /// [unsentChanges], and [changes] hears only when the tournée on changed
  /// with them (a validation).
  Future<void> _keep({required Round? open, List<UnsentRound>? unsent}) {
    if (open != openRound || unsent == null) {
      openRound = open;
      _changes.add(open);
    }
    if (unsent != null) {
      this.unsent = List.unmodifiable(unsent);
      _unsentChanges.add(this.unsent);
    }
    return _file.write(roundsToJson((open: open, unsent: this.unsent)));
  }
}
