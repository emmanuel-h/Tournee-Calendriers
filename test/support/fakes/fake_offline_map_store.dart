// A hand-written OfflineMapStore: regions in memory, each download playing
// a script the test gives, and a log of what happened in order, so a test
// can assert that a new region came before the old one was deleted.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

final class FakeOfflineMapStore implements OfflineMapStore {
  /// A phone that holds [regions] already (none by default).
  FakeOfflineMapStore([Iterable<OfflineMapRegion> regions = const []])
    : _regions = [...regions];

  final List<OfflineMapRegion> _regions;

  /// The events each next download gives, in turn, then the stream ends;
  /// once used up, a download gives [MapDownloadDone] of [defaultBytes].
  /// A null script gives nothing and never ends: a stalled download.
  final scripts = <List<MapDownloadEvent>?>[];

  /// The size of a download with no script left.
  var defaultBytes = 7000000;

  /// What happened, in order: `create <id> <tournee>`, `delete <id>`,
  /// `cancel <id>`.
  final log = <String>[];

  /// The bounds of every download asked, in order.
  final downloadedBounds = <GeoBounds>[];

  /// When set, [regions] fails with it, as a broken database would.
  Error? regionsError;

  var _nextId = 1;

  /// The regions on the phone now.
  List<OfflineMapRegion> get current => List.unmodifiable(_regions);

  @override
  Future<List<OfflineMapRegion>> regions() async {
    if (regionsError case final error?) throw error;
    return [..._regions];
  }

  @override
  Stream<MapDownloadEvent> download(TourneeId tournee, GeoBounds bounds) {
    downloadedBounds.add(bounds);
    final script = scripts.isEmpty
        ? [MapDownloadDone(bytes: defaultBytes)]
        : scripts.removeAt(0);
    late final StreamController<MapDownloadEvent> controller;
    OfflineMapRegion? region;
    var ended = false;
    controller = StreamController<MapDownloadEvent>(
      onListen: () async {
        // As the map library does: the region exists from the start of the
        // download, complete or not.
        final made = OfflineMapRegion(
          id: _nextId++,
          tournee: tournee,
          bounds: bounds,
        );
        region = made;
        _regions.add(made);
        log.add('create ${made.id} ${tournee.value}');
        if (script == null) return;
        for (final event in script) {
          await Future<void>.delayed(Duration.zero);
          if (ended) return;
          if (event is MapDownloadFailed) _remove(made);
          controller.add(event);
        }
        ended = true;
        await controller.close();
      },
      onCancel: () {
        if (ended) return;
        ended = true;
        if (region case final made?) {
          log.add('cancel ${made.id}');
          _remove(made);
        }
      },
    );
    return controller.stream;
  }

  void _remove(OfflineMapRegion region) => _regions.remove(region);

  @override
  Future<void> delete(OfflineMapRegion region) async {
    log.add('delete ${region.id}');
    _regions.remove(region);
  }
}
