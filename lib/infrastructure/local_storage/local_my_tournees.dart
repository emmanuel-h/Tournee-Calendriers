import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/my_tournees_json_mapper.dart';

/// The [MyTourneesStore] of the phone: `my_tournees.json` in the storage
/// folder (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever: the last tournée reopens after an offline cold
/// start.
final class LocalMyTournees implements MyTourneesStore {
  LocalMyTournees._(this._file, this.myTournees);

  /// Reads « Mes tournées » kept in [file]. A missing or unreadable file
  /// means none: the app then starts as on a first launch, and the next
  /// change writes the file again. The file is left as it is until then.
  static Future<LocalMyTournees> load(File file) async {
    final stored = JsonFile(file);
    var mine = MyTournees.none;
    try {
      if (await stored.read() case final json?) {
        mine = myTourneesFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalMyTournees._(stored, mine);
  }

  final JsonFile _file;

  // `broadcast`: several screens may listen at once (the title, the
  // sheet, the streets of the open tournée).
  final _changes = StreamController<MyTournees>.broadcast();

  @override
  MyTournees myTournees;

  @override
  Stream<MyTournees> get changes => _changes.stream;

  @override
  Future<void> save(MyTournees myTournees) {
    this.myTournees = myTournees;
    _changes.add(myTournees);
    return _file.write(myTourneesToJson(myTournees));
  }
}
