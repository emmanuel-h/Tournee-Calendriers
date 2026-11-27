import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

/// What the member on the phone may do as an administrator (PLAN §5.23),
/// for every screen that shows or hides what only admins may do.
/// Not `autoDispose`: once followed, the grants stay known while the app
/// runs, so the screens never flicker back to « not an admin ».
final adminProvider = NotifierProvider<AdminNotifier, AdminGrants>(
  AdminNotifier.new,
);

/// Follows `AdminStatus` for the phone: [AdminGrants.none] until known,
/// and when it cannot be followed, so nothing admin-only shows unless the
/// server (or the phone's copy of its answer) said so. The security rules
/// refuse what the phone may not send anyway.
final class AdminNotifier extends Notifier<AdminGrants> {
  @override
  AdminGrants build() {
    final listening = ref
        .watch(observeAdminStatusProvider)()
        .listen(
          (grants) => state = grants,
          onError: (Object _) => state = AdminGrants.none,
        );
    ref.onDispose(() => unawaited(listening.cancel()));
    return AdminGrants.none;
  }
}

/// The permissions the phone holds in the centre de secours of the open
/// secteur (PLAN §5.23): « Nouveau code », « Retirer », « Rejoindre »,
/// the streets of a secteur visited… show only with theirs. None when no
/// secteur is open.
///
/// A plain `Provider` computed from two others: built again when the
/// grants or the open secteur change, and the screens watching it are
/// only rebuilt when the set itself changes.
final openSectorPermissionsProvider = Provider<Set<Permission>>((ref) {
  final centre = ref.watch(
    currentSectorProvider.select((sector) => sector?.centre.key),
  );
  if (centre == null) return const {};
  return ref.watch(adminProvider.select((grants) => grants.inCentre(centre)));
});

/// Whether the member on the phone prepares the streets shown (PLAN §5.14,
/// §5.23): those of the phone when no secteur is open, and an active
/// member's do; an admin who only visits the secteur needs « Rues » in its
/// CS (« Modifier la rue »). A request still waiting is never the open
/// secteur.
final canPrepareStreetsProvider = Provider<bool>((ref) {
  final visiting = ref.watch(
    currentSectorProvider.select((sector) => sector?.isVisiting ?? false),
  );
  if (!visiting) return true;
  return ref.watch(openSectorPermissionsProvider).contains(Permission.streets);
});
