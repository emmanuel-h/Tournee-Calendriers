import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../support/fakes/fake_member_account.dart';

/// Lets every pending future run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final lea = MemberId('uid-lea');
  late FakeMemberAccount account;
  late ProviderContainer container;
  late ProviderSubscription<AccountState> screen;

  /// Opens a screen that shows the account, with [phone] as the account.
  void open(FakeMemberAccount phone) {
    account = phone;
    container = ProviderContainer(
      overrides: [memberAccountProvider.overrideWithValue(account)],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive, as the screen does
    // while it shows.
    screen = container.listen(accountProvider, (_, _) {});
  }

  AccountState state() => container.read(accountProvider);
  AccountNotifier notifier() => container.read(accountProvider.notifier);

  group('when the screen opens', () {
    test('should be signed in at once when the phone has an account', () async {
      open(FakeMemberAccount(signedInMember: lea));

      expect(state(), AccountSignedIn(lea));
      await _settle();
      expect(account.signInCalls, 0);
    });

    test('should be signing in while the sign-in is on its way', () async {
      open(FakeMemberAccount(nextMember: lea)..gate = Completer<void>());
      await _settle();

      expect(state(), const AccountSigningIn());
      expect(account.signInCalls, 1);
    });

    test('should be signed in once the sign-in succeeds', () async {
      open(FakeMemberAccount(nextMember: lea));

      await _settle();

      expect(state(), AccountSignedIn(lea));
    });

    test('should be offline when the sign-in fails', () async {
      open(FakeMemberAccount());

      await _settle();

      expect(state(), const AccountOffline());
    });

    test('should forget the sign-in when the screen left meanwhile', () async {
      open(FakeMemberAccount(nextMember: lea)..gate = Completer<void>());
      await _settle();

      screen.close();
      await _settle();
      account.gate.complete();
      await _settle();

      // Opened again, the screen starts from what the phone knows now.
      container.listen(accountProvider, (_, _) {});
      expect(state(), AccountSignedIn(lea));
      expect(account.signInCalls, 1);
    });
  });

  group('« Réessayer »', () {
    test('should sign in when the network is back', () async {
      open(FakeMemberAccount());
      await _settle();
      account
        ..nextMember = lea
        ..gate = Completer<void>();

      final retrying = notifier().retry();

      expect(state(), const AccountSigningIn());
      account.gate.complete();
      await retrying;
      expect(state(), AccountSignedIn(lea));
      expect(account.signInCalls, 2);
    });

    test('should be offline again when still offline', () async {
      open(FakeMemberAccount());
      await _settle();

      await notifier().retry();

      expect(state(), const AccountOffline());
      expect(account.signInCalls, 2);
    });

    test('should not sign in twice while signing in', () async {
      open(FakeMemberAccount(nextMember: lea)..gate = Completer<void>());
      await _settle();

      await notifier().retry();

      expect(state(), const AccountSigningIn());
      expect(account.signInCalls, 1);
    });

    test('should do nothing when signed in', () async {
      open(FakeMemberAccount(signedInMember: lea));

      await notifier().retry();

      expect(state(), AccountSignedIn(lea));
      expect(account.signInCalls, 0);
    });
  });
}
