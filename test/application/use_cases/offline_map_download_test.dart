// Following a map download: its progress, then exactly one last word,
// whatever the map library does.
import 'dart:async';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/use_cases/offline_map_download.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import 'offline_fixtures.dart';

void main() {
  test('should pass the progress on, then the end', () async {
    final events = await followMapDownload(
      _Scripted(
        Stream.fromIterable(const [
          MapDownloadProgress(fraction: 0.5, bytes: 10),
          MapDownloadDone(bytes: 20),
        ]),
      ),
      t49,
      area49,
      stallLimit: const Duration(minutes: 1),
    ).toList();

    expect(events, const [
      MapDownloadProgress(fraction: 0.5, bytes: 10),
      MapDownloadDone(bytes: 20),
    ]);
  });

  test('should fail when the map library breaks', () async {
    final events = await followMapDownload(
      _Scripted(Stream.error(StateError('db'))),
      t49,
      area49,
      stallLimit: const Duration(minutes: 1),
    ).toList();

    expect(events, const [MapDownloadFailed()]);
  });

  test('should wait again after each progress before giving up', () async {
    final source = StreamController<MapDownloadEvent>();
    addTearDown(source.close);
    final events = <MapDownloadEvent>[];
    final done = followMapDownload(
      _Scripted(source.stream),
      t49,
      area49,
      stallLimit: const Duration(milliseconds: 40),
    ).listen(events.add).asFuture<void>();

    for (var i = 1; i <= 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.add(MapDownloadProgress(fraction: i / 4, bytes: i));
    }
    source.add(const MapDownloadDone(bytes: 4));
    await done;

    expect(events.last, const MapDownloadDone(bytes: 4));
    expect(events, hasLength(4));
  });
}

/// A store whose download is [events].
final class _Scripted implements OfflineMapStore {
  _Scripted(this.events);

  final Stream<MapDownloadEvent> events;

  @override
  Future<List<OfflineMapRegion>> regions() async => [];

  @override
  Stream<MapDownloadEvent> download(TourneeId tournee, GeoBounds bounds) =>
      events;

  @override
  Future<void> delete(OfflineMapRegion region) async {}
}
