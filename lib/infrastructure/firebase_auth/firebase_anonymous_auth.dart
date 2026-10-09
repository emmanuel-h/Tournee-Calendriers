import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';

/// [AnonymousAuth] over the real Firebase Authentication.
///
/// Thin glue over the SDK, which needs the real platform: proved by the
/// instrumented suite and on the phone, not by unit tests.
final class FirebaseAnonymousAuth implements AnonymousAuth {
  const FirebaseAnonymousAuth(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<void> signIn() async {
    try {
      await _auth.signInAnonymously();
    } on FirebaseException catch (error) {
      // Offline at the very first start (or Firebase unreachable): nothing
      // the user can act on, the next start tries again (PLAN §7). Logged
      // (`adb logcat`) because a project set up wrong fails the same way.
      debugPrint('Anonymous sign-in failed: ${error.code}');
    }
  }
}
