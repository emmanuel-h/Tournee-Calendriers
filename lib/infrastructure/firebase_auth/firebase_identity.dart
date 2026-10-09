import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';

/// The [IdentityProvider] of M2: the member is the uid of the phone's
/// anonymous Firebase account (PLAN §8.3).
///
/// Firebase keeps the account on the phone, so after the first sign-in the
/// uid is known at every start, offline included, and stays the same until
/// the app is removed. Before that first sign-in (the very first start,
/// when offline) the marks are stamped with [beforeSignIn], the id the
/// phone made for itself in M1: marking never waits for the network.
final class FirebaseIdentity implements IdentityProvider {
  // `this._beforeSignIn` as a named parameter: callers write it without the
  // underscore, `beforeSignIn:`.
  FirebaseIdentity(this._auth, {required this._beforeSignIn});

  final AnonymousAuth _auth;
  final IdentityProvider _beforeSignIn;

  /// Read at each change rather than kept, so the uid takes over as soon as
  /// a sign-in started in the background completes.
  @override
  MemberId get currentMember {
    final uid = _auth.currentUid;
    return uid == null ? _beforeSignIn.currentMember : MemberId(uid);
  }

  /// Signs in anonymously unless the phone already has an account. The
  /// composition root starts it without waiting for it: an offline start
  /// must not hang on the network.
  Future<void> signInIfNeeded() async {
    if (_auth.currentUid != null) return;
    await _auth.signIn();
  }
}
