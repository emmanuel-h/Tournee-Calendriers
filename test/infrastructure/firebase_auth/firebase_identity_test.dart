import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/infrastructure/firebase_auth/firebase_identity.dart';

import '../../support/fakes/fake_anonymous_auth.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/results.dart';

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

  group('as the member account', () {
    test('should give the kept uid when the phone signed in before', () {
      final identity = FirebaseIdentity(
        FakeAnonymousAuth(currentUid: 'uid-kept'),
        beforeSignIn: phone,
      );

      expect(identity.signedInMember, MemberId('uid-kept'));
    });

    test('should give no member when nobody signed in yet', () {
      final identity = FirebaseIdentity(
        FakeAnonymousAuth(nextUid: 'uid-new'),
        beforeSignIn: phone,
      );

      expect(identity.signedInMember, isNull);
    });

    test('should answer with the kept uid without signing in', () async {
      final auth = FakeAnonymousAuth(currentUid: 'uid-kept');
      final identity = FirebaseIdentity(auth, beforeSignIn: phone);

      final member = valueOf(await identity.signInIfNeeded());

      expect(member, MemberId('uid-kept'));
      expect(auth.signInCalls, 0);
    });

    test('should answer with the new uid once signed in', () async {
      final auth = FakeAnonymousAuth(nextUid: 'uid-new');
      final identity = FirebaseIdentity(auth, beforeSignIn: phone);

      final member = valueOf(await identity.signInIfNeeded());

      expect(member, MemberId('uid-new'));
      expect(identity.signedInMember, MemberId('uid-new'));
    });

    test('should fail with no network when the sign-in fails', () async {
      final identity = FirebaseIdentity(
        FakeAnonymousAuth(),
        beforeSignIn: phone,
      );

      final failure = failureOf(await identity.signInIfNeeded());

      expect(failure, SignInFailure.noNetwork);
      expect(identity.signedInMember, isNull);
    });

    test('should sign in again when the network is back', () async {
      final auth = FakeAnonymousAuth();
      final identity = FirebaseIdentity(auth, beforeSignIn: phone);
      failureOf(await identity.signInIfNeeded());

      auth.nextUid = 'uid-new';
      final member = valueOf(await identity.signInIfNeeded());

      expect(member, MemberId('uid-new'));
      expect(auth.signInCalls, 2);
    });

    test('should wait for the sign-in on its way, not start another', () async {
      final auth = FakeAnonymousAuth(nextUid: 'uid-new')
        ..gate = Completer<void>();
      final identity = FirebaseIdentity(auth, beforeSignIn: phone);

      final atLaunch = identity.signInIfNeeded();
      final onCreate = identity.signInIfNeeded();
      auth.gate.complete();

      expect(valueOf(await atLaunch), MemberId('uid-new'));
      expect(valueOf(await onCreate), MemberId('uid-new'));
      expect(auth.signInCalls, 1);
    });

    test('should sign in again after a sign-in that threw', () async {
      final auth = FakeAnonymousAuth(nextUid: 'uid-new')
        ..error = const SocketException('unexpected');
      final identity = FirebaseIdentity(auth, beforeSignIn: phone);
      await expectLater(
        identity.signInIfNeeded(),
        throwsA(isA<SocketException>()),
      );

      final member = valueOf(await identity.signInIfNeeded());

      expect(member, MemberId('uid-new'));
      expect(auth.signInCalls, 2);
    });
  });
}
