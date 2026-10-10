import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

// The member's account on the server, which creating or joining a tournée
// needs (PLAN §8.3). Two use cases: one reads what the phone already knows,
// for a screen to show at once, the other asks the server when it must.

/// The member when the phone already has an account, null before the
/// first sign-in. Synchronous: the account is kept on the phone.
final class ReadSignedInMember {
  const ReadSignedInMember(this._account);

  final MemberAccount _account;

  MemberId? call() => _account.signedInMember;
}

/// The member, signing in first when the phone has no account yet: waits
/// for a sign-in already on its way, tries again after one that failed.
/// Fails with [SignInFailure.noNetwork] offline (« hors ligne »).
final class SignIn {
  const SignIn(this._account);

  final MemberAccount _account;

  Future<Result<MemberId, SignInFailure>> call() => _account.signInIfNeeded();
}
