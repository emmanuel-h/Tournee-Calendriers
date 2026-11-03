import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/open_round_json_mapper.dart';

/// The [OpenRoundStore] of the phone: `open_round.json` in the storage
/// folder (PLAN §6.3), read once at start-up, then answered from memory and
/// written again whole at each change. No network, ever: a tournée
/// survives a kill and an offline cold start.
final class LocalOpenRound implements OpenRoundStore {
  LocalOpenRound._(this._file, this.openRound);

  /// Reads the tournée kept in [file]. A missing or unreadable file means
  /// none; the file is left as it is until the next change.
  static Future<LocalOpenRound> load(File file) async {
    final stored = JsonFile(file);
    Round? round;
    try {
      round = openRoundFromJson(await stored.read() ?? _none);
    } on FormatException {
      // Not JSON, or not our schema: no tournée on.
    }
    return LocalOpenRound._(stored, round);
  }

  /// What a missing file stands for: no tournée on.
  static final _none = openRoundToJson(null);

  final JsonFile _file;

  // `broadcast`: Accueil's card and the street screen's may listen at once.
  final _changes = StreamController<Round?>.broadcast();

  @override
  Round? openRound;

  @override
  Stream<Round?> get changes => _changes.stream;

  @override
  Future<void> save(Round round) => _keep(round);

  @override
  Future<void> clear() => _keep(null);

  /// Answers [round] at once, then writes it (queued after the writes
  /// already asked, so two quick dons reach the disk in order).
  Future<void> _keep(Round? round) {
    openRound = round;
    _changes.add(round);
    return _file.write(openRoundToJson(round));
  }
}
