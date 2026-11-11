import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/sector_loss_notice.dart';

/// The last secteur the member lost, for the whole app. Not `autoDispose`:
/// the member may be removed whatever screen is shown, so the app listens
/// to it from its root as long as it runs.
final sectorLossProvider =
    NotifierProvider<SectorLossNotifier, SectorLossNotice?>(
      SectorLossNotifier.new,
    );

/// Follows whether the member is still in each of their secteurs (PLAN
/// §5.3, §5.8). When the server says they were removed, or the secteur
/// deleted, the phone forgets it (none open any more if it was the open
/// one) and [state] tells it, for the app to say so over the next screen.
///
/// Null until a secteur is lost. Offline the server says nothing, so no
/// secteur is ever forgotten without the network (PLAN §7).
///
/// While it follows a secteur it also listens to the member's first name
/// the server holds there, and sends the phone's own when they differ
/// (`CatchUpMemberName`, PLAN §5.9): a name changed while the request
/// waited, or while the secteur could not be read offline, reaches the
/// team as soon as the server is heard. This changes nothing in [state].
///
/// A phone that never signed in has no member to follow the secteurs as:
/// it follows nothing until a sign-in succeeds, then starts again from the
/// secteurs the phone keeps then.
final class SectorLossNotifier extends Notifier<SectorLossNotice?> {
  /// The listeners of each secteur the member is in, by secteur: its
  /// membership and the member's name there. `Object?`: a subscription to
  /// a stream of anything, so both fit in one list (`StreamSubscription`
  /// is covariant in its type, like every Dart generic).
  final _memberships = <SectorId, List<StreamSubscription<Object?>>>{};

  /// Whether each secteur followed is followed as one an admin only
  /// visits (PLAN §5.12): it is followed otherwise (the secteur and the
  /// admin document, not the member document), so once the admin joins it
  /// it must be followed again, as a member's.
  final _visits = <SectorId, bool>{};

  @override
  SectorLossNotice? build() {
    // Every change of « Mes secteurs »: a request accepted adds a secteur
    // to follow, a secteur left or lost removes one.
    final changes = ref.watch(observeMySectorsProvider)().listen(_follow);
    // The account known at last (the sign-in started at launch, or a retry
    // of « Créer » / « Rejoindre »): the secteurs followed until now were
    // followed as nobody, and heard nothing.
    final signIns = ref
        .watch(observeSignInProvider)()
        .listen((_) => _restart());
    ref.onDispose(() {
      unawaited(changes.cancel());
      unawaited(signIns.cancel());
      _stopAll();
    });
    _follow(ref.watch(readMySectorsProvider)());
    return null;
  }

  /// Stops every listener and listens again to the secteurs the phone
  /// keeps now. `ref.read`, not `ref.watch`: outside `build`, reading must
  /// not tie the notifier to the provider again.
  void _restart() {
    _stopAll();
    _follow(ref.read(readMySectorsProvider)());
  }

  void _stopAll() {
    _memberships.values.forEach(_cancel);
    _memberships.clear();
    _visits.clear();
  }

  void _cancel(List<StreamSubscription<Object?>> listeners) {
    for (final listener in listeners) {
      unawaited(listener.cancel());
    }
  }

  /// Listens once to each secteur of [mine] the member is in (a request
  /// is followed by « Mes secteurs » until it is answered), and stops
  /// listening to the others.
  void _follow(MySectors mine) {
    final kept = {
      for (final sector in mine.sectors)
        if (!sector.isPending) sector.id: sector,
    };
    for (final id in _memberships.keys.toList()) {
      final sector = kept[id];
      if (sector == null || sector.isVisiting != _visits.remove(id)) {
        _cancel(_memberships.remove(id)!);
      }
    }
    for (final MapEntry(key: id, value: sector) in kept.entries) {
      _visits[id] = sector.isVisiting;
      _memberships.putIfAbsent(
        id,
        () => [
          ref
              .read(watchMembershipProvider)(sector)
              .listen(
                (loss) => unawaited(_forget(id, loss)),
                // A listener that fails (a server error) keeps the
                // secteur: only the server's answer may make the phone
                // forget it.
                onError: (Object _) {},
              ),
          ref
              .read(watchOwnNameProvider)(id)
              .listen(
                (heard) =>
                    unawaited(ref.read(catchUpMemberNameProvider)(id, heard)),
                // A listener that fails sends nothing: the name catches up
                // at the next launch or sign-in.
                onError: (Object _) {},
              ),
        ],
      );
    }
  }

  Future<void> _forget(SectorId id, SectorLoss loss) async {
    final lost = await ref.read(forgetLostSectorProvider)(id, loss);
    // Gone already (left meanwhile), or the app went away while the phone
    // forgot it: nothing to tell.
    if (lost == null || !ref.mounted) return;
    state = SectorLossNotice(
      sector: lost.sector.id,
      number: lost.sector.number.value,
      loss: lost.loss,
      wasOpen: lost.wasOpen,
    );
  }
}
