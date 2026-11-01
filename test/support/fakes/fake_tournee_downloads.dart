// An in-memory TourneeDownloads: no file, answers at once, and tells each
// change, as the phone's adapter does.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

final class FakeTourneeDownloads implements TourneeDownloads {
  /// A phone that downloaded [downloads] already (none by default).
  FakeTourneeDownloads([Iterable<TourneeDownload> downloads = const []])
    : _downloads = {
        for (final download in downloads) download.tournee: download,
      };

  final Map<TourneeId, TourneeDownload> _downloads;

  // `sync: true`: a listener hears a change before `save` returns.
  final _changes = StreamController<Map<TourneeId, TourneeDownload>>.broadcast(
    sync: true,
  );

  @override
  Map<TourneeId, TourneeDownload> get downloads => Map.unmodifiable(_downloads);

  @override
  Stream<Map<TourneeId, TourneeDownload>> get changes => _changes.stream;

  @override
  Future<void> save(TourneeDownload download) async {
    _downloads[download.tournee] = download;
    _changes.add(downloads);
  }

  @override
  Future<void> forget(TourneeId tournee) async {
    _downloads.remove(tournee);
    _changes.add(downloads);
  }
}
