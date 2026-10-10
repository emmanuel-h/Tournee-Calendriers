import 'dart:io';

import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/moved_streets_json_mapper.dart';

/// The [MovedStreetsLog] of the phone: `moved_streets.json` in the storage
/// folder (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever.
final class LocalMovedStreetsLog implements MovedStreetsLog {
  LocalMovedStreetsLog._(this._file, this._tournees);

  /// Reads the tournées kept in [file]. A missing or unreadable file means
  /// none: the card is offered again, and moving twice skips the streets
  /// already in the tournée.
  static Future<LocalMovedStreetsLog> load(File file) async {
    final stored = JsonFile(file);
    var tournees = <TourneeId>{};
    try {
      if (await stored.read() case final json?) {
        tournees = movedStreetsFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalMovedStreetsLog._(stored, tournees);
  }

  final JsonFile _file;
  final Set<TourneeId> _tournees;

  @override
  bool wereMovedInto(TourneeId tournee) => _tournees.contains(tournee);

  @override
  Future<void> rememberMovedInto(TourneeId tournee) {
    _tournees.add(tournee);
    return _file.write(movedStreetsToJson(_tournees));
  }
}
