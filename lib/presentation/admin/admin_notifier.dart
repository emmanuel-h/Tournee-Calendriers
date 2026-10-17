import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// Whether the member on the phone is an administrator of the app (PLAN
/// §5.12), for every screen that shows or hides what only admins may do.
/// Not `autoDispose`: once followed, the answer stays known while the app
/// runs, so the screens never flicker back to « not an admin ».
final adminProvider = NotifierProvider<AdminNotifier, bool>(AdminNotifier.new);

/// Follows `AdminStatus` for the phone: false until it is known, and when
/// it cannot be followed, so nothing admin-only shows unless the server
/// (or the phone's copy of its answer) said so. The security rules refuse
/// what a non-admin would send anyway.
final class AdminNotifier extends Notifier<bool> {
  @override
  bool build() {
    final listening = ref
        .watch(observeAdminStatusProvider)()
        .listen(
          (isAdmin) => state = isAdmin,
          onError: (Object _) => state = false,
        );
    ref.onDispose(() => unawaited(listening.cancel()));
    return false;
  }
}
