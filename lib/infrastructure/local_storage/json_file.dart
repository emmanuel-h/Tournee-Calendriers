import 'dart:convert';
import 'dart:io';

import 'package:tournee_calendriers/infrastructure/local_storage/atomic_file.dart';

/// One small JSON file of the phone storage (the street view preferences,
/// « Mes tournées », the settings, PLAN §6.3): read once at start-up, then
/// written again whole after each change.
///
/// Writes are queued: each starts when the one before it has ended, so a
/// quick on-off-on reaches the disk in that order. Each goes through
/// [writeAtomically], so a kill mid-write leaves the old content.
final class JsonFile {
  JsonFile(this.file);

  final File file;

  /// The last write asked; the next one starts when it ends.
  Future<void> _lastWrite = Future.value();

  /// The decoded content of [file]; null when there is no file yet (a first
  /// launch). Throws a [FormatException] when the file is not JSON or not
  /// valid UTF-8, so the caller treats it like JSON of the wrong schema.
  Future<Object?> read() async {
    // A sync check: `File.exists` would cost a round trip to another thread
    // for a call this small (the `avoid_slow_async_io` lint).
    if (!file.existsSync()) return null;
    final String text;
    try {
      text = await file.readAsString();
    } on FileSystemException catch (error) {
      throw FormatException('Not UTF-8: ${error.message}');
    }
    return jsonDecode(text);
  }

  /// Writes [json] after the writes already asked, creating the folder on
  /// the first one. The text is made now, so a later change cannot slip
  /// into this write.
  Future<void> write(Object? json) async {
    final text = jsonEncode(json);
    final write = _lastWrite.then((_) async {
      await file.parent.create(recursive: true);
      await writeAtomically(file, text);
    });
    // A failed write must not block the ones after it; the caller still
    // gets its error through `write`.
    _lastWrite = write.then<void>((_) {}, onError: (Object _) {});
    await write;
  }
}
