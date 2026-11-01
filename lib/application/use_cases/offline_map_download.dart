import 'dart:async';

import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// The download of a map region of [bounds] for [tournee] from [maps],
/// with its progress, ending with exactly one [MapDownloadDone] or
/// [MapDownloadFailed].
///
/// Offline, the map library never says it failed: it waits for the
/// network and tries again, for ever. So a download that tells nothing for
/// [stallLimit] fails, and its half-made region goes (cancelling the
/// store's stream deletes it). A stream that ends without its last word,
/// or with an error, fails too. Cancelling the returned stream cancels the
/// store's at once.
Stream<MapDownloadEvent> followMapDownload(
  OfflineMapStore maps,
  TourneeId tournee,
  GeoBounds bounds, {
  required Duration stallLimit,
}) {
  // A `StreamController` makes a stream by hand: what is `add`ed to it
  // reaches the listener, and `onCancel` runs when the listener stops.
  late final StreamController<MapDownloadEvent> out;
  StreamSubscription<MapDownloadEvent>? source;
  Timer? stall;

  void finish(MapDownloadEvent last) {
    if (out.isClosed) return;
    stall?.cancel();
    out.add(last);
    unawaited(out.close());
    unawaited(source?.cancel());
  }

  void watchForStall() {
    stall?.cancel();
    stall = Timer(stallLimit, () => finish(const MapDownloadFailed()));
  }

  out = StreamController<MapDownloadEvent>(
    onListen: () {
      watchForStall();
      source = maps
          .download(tournee, bounds)
          .listen(
            (event) {
              if (event is MapDownloadProgress) {
                watchForStall();
                out.add(event);
              } else {
                finish(event);
              }
            },
            onError: (Object _) => finish(const MapDownloadFailed()),
            onDone: () => finish(const MapDownloadFailed()),
          );
    },
    onCancel: () {
      stall?.cancel();
      return source?.cancel();
    },
  );
  return out.stream;
}
