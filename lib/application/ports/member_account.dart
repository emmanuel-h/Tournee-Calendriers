import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why the phone has no account on the server yet.
enum SignInFailure {
  /// The phone could not reach the server. Only the very first sign-in
  /// needs it: once done, the account is kept on the phone (PLAN §7).
  noNetwork,
}

/// The member's account on the server: the anonymous account whose uid is
/// the member id of the team (PLAN §8.3).
///
/// An application port: the use cases own it, the Firebase adapter of
/// `infrastructure/firebase_auth/` implements it.
///
/// `IdentityProvider` stamps the marks and never waits: before the first
/// sign-in it stands in with the phone's own id. Creating or joining a
/// tournée cannot do that: the server only lets in the account's uid
/// (PLAN §8.2), so they ask this port, which waits for the account or
/// tells there is none yet (« hors ligne »).
abstract interface class MemberAccount {
  /// The member, once the phone has an account; null before the first
  /// sign-in succeeded. Read from the phone: no network, no waiting.
  MemberId? get signedInMember;

  /// The member, signing in first when the phone has no account yet.
  ///
  /// Each call when there is still none tries again, so a phone started
  /// offline gets its account as soon as it is asked with the network
  /// back, without restarting the app. A sign-in already on its way (the
  /// one started at launch) is waited for rather than started twice.
  /// Fails with [SignInFailure.noNetwork] when the server is out of reach.
  Future<Result<MemberId, SignInFailure>> signInIfNeeded();
}
