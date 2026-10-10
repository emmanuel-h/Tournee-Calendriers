import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The account of the phone, as the screens that create or join a tournée
/// show it. `autoDispose`: built again each time such a screen opens, so
/// opening it is already a new try when the first start was offline.
final accountProvider =
    NotifierProvider.autoDispose<AccountNotifier, AccountState>(
      AccountNotifier.new,
    );

/// Gets the phone its account on the server (PLAN §8.3) for « Créer » and
/// « Rejoindre », and tells the screen when it cannot (« hors ligne »).
///
/// Nothing here runs at launch: the street screens never build it, so an
/// offline cold start opens them as before.
final class AccountNotifier extends Notifier<AccountState> {
  @override
  AccountState build() {
    // Known from the phone: a phone that signed in once shows no wait.
    final member = ref.read(readSignedInMemberProvider)();
    if (member != null) return AccountSignedIn(member);
    // Usually waits for the sign-in started at launch; tries again when
    // that one has already failed. `unawaited`: `build` must return the
    // state now, the answer sets it later.
    unawaited(_signIn());
    return const AccountSigningIn();
  }

  /// « Réessayer », shown while offline. Does nothing otherwise: a sign-in
  /// on its way is already being waited for.
  Future<void> retry() async {
    if (state is! AccountOffline) return;
    state = const AccountSigningIn();
    await _signIn();
  }

  Future<void> _signIn() async {
    final signedIn = await ref.read(signInProvider)();
    // The screen may have closed while the server answered.
    if (!ref.mounted) return;
    state = switch (signedIn) {
      Ok(:final value) => AccountSignedIn(value),
      Err(:final failure) => switch (failure) {
        SignInFailure.noNetwork => const AccountOffline(),
      },
    };
  }
}
