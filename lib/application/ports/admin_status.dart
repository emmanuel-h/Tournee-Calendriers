import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// What the administrator on the phone may do (PLAN §5.23): their
/// `admins/{uid}` document, its CS grants written by the super admin and
/// its global permissions only in the Firebase console.
///
/// An application port: the use cases own it, a Firestore adapter of
/// `infrastructure/` implements it, tests use a fake. The security rules
/// check the same document, so the app only uses the answer to show or
/// hide what an admin may do.
abstract interface class AdminStatus {
  /// The grants of the member using the phone, now and after each change.
  /// [AdminGrants.none] until the answer is known (nothing admin-only shows
  /// before), while the phone has no account yet, and for a member who is
  /// no admin. Once read, the answer is kept on the phone, so it is known
  /// offline after a restart.
  Stream<AdminGrants> watchGrants();

  /// Whether [member] is an admin (« Léa · admin » in Équipe): whether
  /// their `admins/{uid}` document exists, whatever it grants, so nothing
  /// tells a super admin from another. False when it cannot be told
  /// (offline, never read).
  Future<bool> isAdmin(MemberId member);
}
