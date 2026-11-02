// An in-memory SectorDownloads: no file, answers at once, and tells each
// change, as the phone's adapter does.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

final class FakeSectorDownloads implements SectorDownloads {
  /// A phone that downloaded [downloads] already (none by default).
  FakeSectorDownloads([Iterable<SectorDownload> downloads = const []])
    : _downloads = {
        for (final download in downloads) download.sector: download,
      };

  final Map<SectorId, SectorDownload> _downloads;

  // `sync: true`: a listener hears a change before `save` returns.
  final _changes = StreamController<Map<SectorId, SectorDownload>>.broadcast(
    sync: true,
  );

  @override
  Map<SectorId, SectorDownload> get downloads => Map.unmodifiable(_downloads);

  @override
  Stream<Map<SectorId, SectorDownload>> get changes => _changes.stream;

  @override
  Future<void> save(SectorDownload download) async {
    _downloads[download.sector] = download;
    _changes.add(downloads);
  }

  @override
  Future<void> forget(SectorId sector) async {
    _downloads.remove(sector);
    _changes.add(downloads);
  }
}
