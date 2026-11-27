import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';

/// « Identifiant de l'appareil » at the bottom of Bienvenue and in
/// Paramètres (PLAN §5.12): the phone's uid, which an admin of the app
/// types into the Firebase console to make this phone an admin.
///
/// `autoDispose`, and built on [accountProvider]: the screen showing it
/// signs the phone in when it opens, so a fresh install gets its uid.
final deviceIdProvider = Provider.autoDispose<DeviceIdState>(
  (ref) => switch (ref.watch(accountProvider)) {
    AccountSignedIn(:final member) => DeviceIdShown(
      member.value,
      role: ref.watch(adminProvider.select((grants) => grants.role)),
    ),
    AccountSigningIn() => const DeviceIdSigningIn(),
    AccountOffline() => const DeviceIdOffline(),
  },
);

/// What the screens show of the phone's uid. `sealed`: each screen's
/// `switch` handles every case.
sealed class DeviceIdState {
  const DeviceIdState();
}

/// The phone is signing in: no uid yet.
final class DeviceIdSigningIn extends DeviceIdState {
  const DeviceIdSigningIn();
}

/// The phone has no account and cannot reach the server (« Pas encore de
/// compte : connectez-vous au réseau. »).
final class DeviceIdOffline extends DeviceIdState {
  const DeviceIdOffline();
}

/// The phone's uid [id], and its [role] (« Administrateur », « Super
/// administrateur », PLAN §5.23): only this phone ever shows it.
final class DeviceIdShown extends DeviceIdState {
  const DeviceIdShown(this.id, {this.role = AdminRole.none});

  /// The whole uid, shown in full and put on the clipboard by the copy
  /// button.
  final String id;
  final AdminRole role;

  @override
  bool operator ==(Object other) =>
      other is DeviceIdShown && other.id == id && other.role == role;

  @override
  int get hashCode => Object.hash(id, role);
}
