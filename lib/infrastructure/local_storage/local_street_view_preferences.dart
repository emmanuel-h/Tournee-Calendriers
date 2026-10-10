import 'dart:io';

import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_view_json_mapper.dart';

/// The [StreetViewPreferences] of the phone: one small JSON file next to
/// the streets (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever.
///
/// A file of the app's own storage rather than `shared_preferences`: the
/// phone storage already writes files safely (see [JsonFile]), and a file
/// in the storage folder needs no platform plugin, works in plain Dart
/// tests, and goes away with the rest when a test or the instrumented suite
/// uses a fresh folder.
final class LocalStreetViewPreferences implements StreetViewPreferences {
  LocalStreetViewPreferences._(this._file, this._hidingDone);

  /// Reads the preferences kept in [file]. A missing or unreadable file
  /// means nothing is hidden: a lost display preference is not worth
  /// stopping the app for, and the next change writes the file again.
  static Future<LocalStreetViewPreferences> load(File file) async {
    final stored = JsonFile(file);
    var hidingDone = <StreetId>{};
    try {
      if (await stored.read() case final json?) {
        hidingDone = streetViewFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalStreetViewPreferences._(stored, hidingDone);
  }

  final JsonFile _file;
  final Set<StreetId> _hidingDone;

  @override
  bool hidesDone(StreetId id) => _hidingDone.contains(id);

  @override
  Future<void> setHidesDone(StreetId id, {required bool hide}) {
    if (hide) {
      _hidingDone.add(id);
    } else {
      _hidingDone.remove(id);
    }
    return _file.write(streetViewToJson(_hidingDone));
  }
}
