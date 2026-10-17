import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      isAdmin: ref.watch(adminProvider),
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

/// The phone's uid [id], and whether it is an admin (« · administrateur »).
final class DeviceIdShown extends DeviceIdState {
  const DeviceIdShown(this.id, {required this.isAdmin});

  /// The whole uid: what the copy button puts on the clipboard.
  final String id;
  final bool isAdmin;

  /// The uid as shown, `x7Fq…9kP2`: its first and last four characters,
  /// enough to compare with the console. Short ids are shown whole.
  String get short => id.length <= 9
      ? id
      : '${id.substring(0, 4)}…${id.substring(id.length - 4)}';

  @override
  bool operator ==(Object other) =>
      other is DeviceIdShown && other.id == id && other.isAdmin == isAdmin;

  @override
  int get hashCode => Object.hash(id, isAdmin);
}
