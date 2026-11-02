import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_state.dart';

/// Which tournées of « Mes tournées » can open now (PLAN §5.3, §7):
/// offline, a tournée never downloaded on this phone has nothing to show,
/// so the sheet greys it (« Disponible avec réseau ») and it cannot be
/// tapped. Immutable: the notifier replaces it as a whole.
final class OfflineAccess {
  OfflineAccess({required this.offline, required Set<SectorId> downloaded})
    : downloaded = Set.unmodifiable(downloaded);

  /// Whether the phone cannot reach the server now.
  final bool offline;

  /// The tournées downloaded on this phone, which open offline too.
  final Set<SectorId> downloaded;

  /// Whether [row] cannot open now: offline, another tournée of the member
  /// not downloaded here. The open tournée is already shown, and a pending
  /// request cannot open anyway (it keeps its own look).
  bool isUnavailable(SectorRow row) =>
      offline &&
      row.status == SectorRowStatus.closed &&
      !downloaded.contains(row.id);

  OfflineAccess _withOffline(bool offline) =>
      OfflineAccess(offline: offline, downloaded: downloaded);

  OfflineAccess _withDownloaded(Iterable<SectorId> downloaded) =>
      OfflineAccess(offline: offline, downloaded: downloaded.toSet());

  @override
  bool operator ==(Object other) =>
      other is OfflineAccess &&
      other.offline == offline &&
      other.downloaded.length == downloaded.length &&
      other.downloaded.containsAll(downloaded);

  @override
  int get hashCode => Object.hash(offline, Object.hashAllUnordered(downloaded));

  @override
  String toString() => 'OfflineAccess(offline: $offline, $downloaded)';
}

/// What « Mes tournées » can open now. `autoDispose`: followed only while
/// the sheet is shown.
final offlineAccessProvider =
    NotifierProvider.autoDispose<OfflineAccessNotifier, OfflineAccess>(
      OfflineAccessNotifier.new,
    );

/// Follows whether the phone is offline (`ObserveOffline`) and which
/// tournées it downloaded (`ObserveSectorDownloads`).
///
/// A provider of its own rather than a part of `mySectorsProvider`: the
/// offline signal comes from the open tournée's streets, which follow
/// `mySectorsProvider`, so that one watching it would go round in a
/// circle.
final class OfflineAccessNotifier extends Notifier<OfflineAccess> {
  @override
  OfflineAccess build() {
    // `ref.watch` on the use case: another tournée opened binds another
    // connection (the new tournée's listener), and this is built again.
    final offline = ref
        .watch(observeOfflineProvider)()
        .listen(
          (offline) => state = state._withOffline(offline),
          // Nothing can tell any more (the member left the tournée): the
          // rows stay as they are online rather than greyed for nothing.
          onError: (Object _) => state = state._withOffline(false),
        );
    final downloads = ref
        .watch(observeSectorDownloadsProvider)()
        .listen((downloads) => state = state._withDownloaded(downloads.keys));
    ref.onDispose(() {
      unawaited(offline.cancel());
      unawaited(downloads.cancel());
    });
    // Online until the listener tells: a row greyed for nothing at each
    // opening would worry more than one tapped in vain. The downloads are
    // on the phone, known at once.
    return OfflineAccess(
      offline: false,
      downloaded: ref.read(readSectorDownloadsProvider)().keys.toSet(),
    );
  }
}
