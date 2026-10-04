import 'dart:convert';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/atomic_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_view_json_mapper.dart';

/// The [StreetViewPreferences] of the phone: one small JSON file next to
/// the streets (PLAN §6.3), read once at start-up and then answered from
/// memory. No network, ever.
///
/// A file of the app's own storage rather than `shared_preferences`: the
/// phone storage already writes files safely (see [writeAtomically]), and a
/// file in the storage folder needs no platform plugin, works in plain Dart
/// tests, and goes away with the rest when a test or the instrumented suite
/// uses a fresh folder.
final class LocalStreetViewPreferences implements StreetViewPreferences {
  LocalStreetViewPreferences._(this._file, this._hidingDone);

  /// Reads the preferences kept in [file]. A missing or unreadable file
  /// means nothing is hidden: a lost display preference is not worth
  /// stopping the app for, and the next change writes the file again.
  static Future<LocalStreetViewPreferences> load(File file) async {
    var hidingDone = <StreetId>{};
    // A sync check: `File.exists` would cost a round trip to another thread
    // for a call this small (the `avoid_slow_async_io` lint).
    if (file.existsSync()) {
      try {
        hidingDone = streetViewFromJson(jsonDecode(await file.readAsString()));
      } on FormatException {
        // Not JSON, or not our schema: start afresh.
      } on FileSystemException {
        // Not valid UTF-8: the same.
      }
    }
    return LocalStreetViewPreferences._(file, hidingDone);
  }

  final File _file;
  final Set<StreetId> _hidingDone;

  /// The last write asked; the next one starts when it ends, so a quick
  /// on-off-on is kept in that order.
  Future<void> _lastWrite = Future.value();

  @override
  bool hidesDone(StreetId id) => _hidingDone.contains(id);

  @override
  Future<void> setHidesDone(StreetId id, {required bool hide}) async {
    if (hide) {
      _hidingDone.add(id);
    } else {
      _hidingDone.remove(id);
    }
    // The text is made now, so a later change cannot slip into this write.
    final text = jsonEncode(streetViewToJson(_hidingDone));
    final write = _lastWrite.then((_) async {
      await _file.parent.create(recursive: true);
      await writeAtomically(_file, text);
    });
    // A failed write must not block the ones after it; the caller still
    // gets its error through `write`.
    _lastWrite = write.then<void>((_) {}, onError: (Object _) {});
    await write;
  }
}
