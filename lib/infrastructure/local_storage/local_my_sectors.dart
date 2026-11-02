import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/my_sectors_json_mapper.dart';

/// The [MySectorsStore] of the phone: `my_tournees.json` in the storage
/// folder (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever: the last tournée reopens after an offline cold
/// start.
final class LocalMySectors implements MySectorsStore {
  LocalMySectors._(this._file, this.mySectors);

  /// Reads « Mes secteurs » kept in [file]. A missing or unreadable file
  /// means none: the app then starts as on a first launch, and the next
  /// change writes the file again. The file is left as it is until then.
  static Future<LocalMySectors> load(File file) async {
    final stored = JsonFile(file);
    var mine = MySectors.none;
    try {
      if (await stored.read() case final json?) {
        mine = mySectorsFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalMySectors._(stored, mine);
  }

  final JsonFile _file;

  // `broadcast`: several screens may listen at once (the title, the
  // sheet, the streets of the open tournée).
  final _changes = StreamController<MySectors>.broadcast();

  @override
  MySectors mySectors;

  @override
  Stream<MySectors> get changes => _changes.stream;

  @override
  Future<void> save(MySectors mySectors) {
    this.mySectors = mySectors;
    _changes.add(mySectors);
    return _file.write(mySectorsToJson(mySectors));
  }
}
