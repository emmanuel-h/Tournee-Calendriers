import 'dart:async';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';

import '../../support/fakes/fake_anonymous_auth.dart';
import '../../support/fakes/fake_ports.dart';

void main() {
  final phone = FakeIdentity(MemberId('phone-id'));

  test('should be the kept uid when the phone signed in before', () {
    final identity = FirebaseIdentity(
      FakeAnonymousAuth(currentUid: 'uid-kept'),
      beforeSignIn: phone,
    );

    expect(identity.currentMember, MemberId('uid-kept'));
  });

  test('should be the phone id when nobody signed in yet', () {
    final identity = FirebaseIdentity(FakeAnonymousAuth(), beforeSignIn: phone);

    expect(identity.currentMember, MemberId('phone-id'));
  });

  test('should sign in when nobody signed in yet', () async {
    final auth = FakeAnonymousAuth(nextUid: 'uid-new');
    final identity = FirebaseIdentity(auth, beforeSignIn: phone);

    await identity.signInIfNeeded();

    expect(auth.signInCalls, 1);
    expect(identity.currentMember, MemberId('uid-new'));
  });

  test('should keep the phone id while the sign-in is on its way', () async {
    final auth = FakeAnonymousAuth(nextUid: 'uid-new')
      ..gate = Completer<void>();
    final identity = FirebaseIdentity(auth, beforeSignIn: phone);

    final signingIn = identity.signInIfNeeded();

    expect(identity.currentMember, MemberId('phone-id'));
    auth.gate.complete();
    await signingIn;
    expect(identity.currentMember, MemberId('uid-new'));
  });

  test('should not sign in again when the phone signed in before', () async {
    final auth = FakeAnonymousAuth(currentUid: 'uid-kept', nextUid: 'uid-new');
    final identity = FirebaseIdentity(auth, beforeSignIn: phone);

    await identity.signInIfNeeded();

    expect(auth.signInCalls, 0);
    expect(identity.currentMember, MemberId('uid-kept'));
  });

  test('should stay the phone id when the sign-in fails offline', () async {
    final auth = FakeAnonymousAuth();
    final identity = FirebaseIdentity(auth, beforeSignIn: phone);

    await identity.signInIfNeeded();

    expect(auth.signInCalls, 1);
    expect(identity.currentMember, MemberId('phone-id'));
  });
}
