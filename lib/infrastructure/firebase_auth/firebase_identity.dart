import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';

/// The [IdentityProvider] of M2: the member is the uid of the phone's
/// anonymous Firebase account (PLAN §8.3). Also the [MemberAccount] that
/// creating or joining a tournée waits for.
///
/// Firebase keeps the account on the phone, so after the first sign-in the
/// uid is known at every start, offline included, and stays the same until
/// the app is removed. Before that first sign-in (the very first start,
/// when offline) the marks are stamped with [beforeSignIn], the id the
/// phone made for itself in M1: marking never waits for the network.
final class FirebaseIdentity implements IdentityProvider, MemberAccount {
  // `this._beforeSignIn` as a named parameter: callers write it without the
  // underscore, `beforeSignIn:`.
  FirebaseIdentity(this._auth, {required this._beforeSignIn});

  final AnonymousAuth _auth;
  final IdentityProvider _beforeSignIn;

  /// The sign-in on its way, null when none is. Every caller in the
  /// meantime waits for this one: two anonymous sign-ins at once could
  /// make two accounts, and the member would be one of them at random.
  Future<void>? _signingIn;

  /// Read at each change rather than kept, so the uid takes over as soon as
  /// a sign-in started in the background completes.
  @override
  MemberId get currentMember => signedInMember ?? _beforeSignIn.currentMember;

  @override
  MemberId? get signedInMember => switch (_auth.currentUid) {
    null => null,
    final uid => MemberId(uid),
  };

  /// Signs in anonymously unless the phone already has an account. The
  /// composition root starts it at launch without waiting for it (an
  /// offline start must not hang on the network); creating or joining a
  /// tournée calls it again, which waits for that one or tries again.
  @override
  Future<Result<MemberId, SignInFailure>> signInIfNeeded() async {
    if (_auth.currentUid == null) await (_signingIn ??= _signIn());
    return switch (signedInMember) {
      null => const Err(SignInFailure.noNetwork),
      final member => Ok(member),
    };
  }

  /// One sign-in, forgotten once over (even if it threw), so the next call
  /// tries again: the network may be back by then.
  Future<void> _signIn() =>
      _auth.signIn().whenComplete(() => _signingIn = null);
}
