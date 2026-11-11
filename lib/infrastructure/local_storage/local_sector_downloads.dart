import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/sector_downloads_json_mapper.dart';

/// The [SectorDownloads] of the phone: `tournee_downloads.json` in the
/// storage folder (PLAN §6.3), read once at start-up and then answered
/// from memory. No network, ever: it answers after an offline cold start.
final class LocalSectorDownloads implements SectorDownloads {
  LocalSectorDownloads._(this._file, this._downloads);

  /// Reads the downloads kept in [file]. A missing or unreadable file
  /// means none: the open secteur is then downloaded again, and the next
  /// download writes the file again.
  static Future<LocalSectorDownloads> load(File file) async {
    final stored = JsonFile(file);
    var downloads = <SectorId, SectorDownload>{};
    try {
      if (await stored.read() case final json?) {
        downloads = sectorDownloadsFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalSectorDownloads._(stored, downloads);
  }

  final JsonFile _file;
  final Map<SectorId, SectorDownload> _downloads;

  // `broadcast`: several listeners may follow it at once.
  final _changes = StreamController<Map<SectorId, SectorDownload>>.broadcast();

  @override
  Map<SectorId, SectorDownload> get downloads => Map.unmodifiable(_downloads);

  @override
  Stream<Map<SectorId, SectorDownload>> get changes => _changes.stream;

  @override
  Future<void> save(SectorDownload download) {
    _downloads[download.sector] = download;
    return _written();
  }

  @override
  Future<void> forget(SectorId sector) {
    if (_downloads.remove(sector) == null) return Future.value();
    return _written();
  }

  Future<void> _written() {
    _changes.add(downloads);
    return _file.write(sectorDownloadsToJson(_downloads));
  }
}
