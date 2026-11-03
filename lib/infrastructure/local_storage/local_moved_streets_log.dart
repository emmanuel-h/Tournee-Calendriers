import 'dart:io';

import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/moved_streets_json_mapper.dart';

/// The [MovedStreetsLog] of the phone: `moved_streets.json` in the storage
/// folder (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever.
final class LocalMovedStreetsLog implements MovedStreetsLog {
  LocalMovedStreetsLog._(this._file, this._sectors);

  /// Reads the tournées kept in [file]. A missing or unreadable file means
  /// none: the card is offered again, and moving twice skips the streets
  /// already in the tournée.
  static Future<LocalMovedStreetsLog> load(File file) async {
    final stored = JsonFile(file);
    var sectors = <SectorId>{};
    try {
      if (await stored.read() case final json?) {
        sectors = movedStreetsFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalMovedStreetsLog._(stored, sectors);
  }

  final JsonFile _file;
  final Set<SectorId> _sectors;

  @override
  bool wereMovedInto(SectorId sector) => _sectors.contains(sector);

  @override
  Future<void> rememberMovedInto(SectorId sector) {
    _sectors.add(sector);
    return _file.write(movedStreetsToJson(_sectors));
  }
}
