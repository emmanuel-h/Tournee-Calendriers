import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/tournee_downloads_json_mapper.dart';

/// The [TourneeDownloads] of the phone: `tournee_downloads.json` in the
/// storage folder (PLAN §6.3), read once at start-up and then answered
/// from memory. No network, ever: it answers after an offline cold start.
final class LocalTourneeDownloads implements TourneeDownloads {
  LocalTourneeDownloads._(this._file, this._downloads);

  /// Reads the downloads kept in [file]. A missing or unreadable file
  /// means none: the open tournée is then downloaded again, and the next
  /// download writes the file again.
  static Future<LocalTourneeDownloads> load(File file) async {
    final stored = JsonFile(file);
    var downloads = <TourneeId, TourneeDownload>{};
    try {
      if (await stored.read() case final json?) {
        downloads = tourneeDownloadsFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalTourneeDownloads._(stored, downloads);
  }

  final JsonFile _file;
  final Map<TourneeId, TourneeDownload> _downloads;

  // `broadcast`: several listeners may follow it at once.
  final _changes =
      StreamController<Map<TourneeId, TourneeDownload>>.broadcast();

  @override
  Map<TourneeId, TourneeDownload> get downloads => Map.unmodifiable(_downloads);

  @override
  Stream<Map<TourneeId, TourneeDownload>> get changes => _changes.stream;

  @override
  Future<void> save(TourneeDownload download) {
    _downloads[download.tournee] = download;
    return _written();
  }

  @override
  Future<void> forget(TourneeId tournee) {
    if (_downloads.remove(tournee) == null) return Future.value();
    return _written();
  }

  Future<void> _written() {
    _changes.add(downloads);
    return _file.write(tourneeDownloadsToJson(_downloads));
  }
}
