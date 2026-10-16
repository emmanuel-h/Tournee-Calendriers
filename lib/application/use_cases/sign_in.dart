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

/// The member, each time a sign-in gives the phone its account (the one
/// started at launch, or a retry of « Créer » / « Rejoindre », PLAN §8.3).
/// What needs the account starts then, without restarting the app.
final class ObserveSignIn {
  const ObserveSignIn(this._account);

  final MemberAccount _account;

  Stream<MemberId> call() => _account.signIns;
}
