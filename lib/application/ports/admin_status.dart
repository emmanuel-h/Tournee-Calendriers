import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Who is an administrator of the app (PLAN §5.12): an `admins/{uid}`
/// document added by hand in the Firebase console, never from the app.
/// Admins are global: they create tournées and manage every one, member of
/// it or not.
///
/// An application port: the use cases own it, a Firestore adapter of
/// `infrastructure/` implements it, tests use a fake. The security rules
/// check the same document, so the app only uses the answer to show or
/// hide what an admin may do.
abstract interface class AdminStatus {
  /// Whether the member using the phone is an admin, now and after each
  /// change. False until the answer is known (nothing admin-only shows
  /// before), and while the phone has no account yet. Once read, the
  /// answer is kept on the phone, so it is known offline after a restart.
  Stream<bool> watchIsAdmin();

  /// Whether [member] is an admin (« Léa · admin » in Équipe). False when
  /// it cannot be told (offline, never read).
  Future<bool> isAdmin(MemberId member);
}
