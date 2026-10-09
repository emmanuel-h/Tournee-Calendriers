import 'dart:async';

import 'package:tournee_calendriers/infrastructure/firebase_auth/anonymous_auth.dart';

/// A sign-in service in memory. [currentUid] is the session kept on the
/// phone; [signIn] gives [nextUid] (or nothing, like an offline phone, when
/// it is null) once [gate] completes, so a test can look at the app while
/// the sign-in is still on its way.
final class FakeAnonymousAuth implements AnonymousAuth {
  FakeAnonymousAuth({this.currentUid, this.nextUid});

  @override
  String? currentUid;

  /// The uid the next [signIn] gives; null makes it fail.
  String? nextUid;

  /// Completed by the test to let [signIn] finish; already done by default.
  Completer<void> gate = Completer<void>()..complete();

  var signInCalls = 0;

  @override
  Future<void> signIn() async {
    signInCalls++;
    await gate.future;
    currentUid ??= nextUid;
  }
}
