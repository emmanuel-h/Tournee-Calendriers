import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Whether the phone has its account on the server, which « Créer » and
/// « Rejoindre » need (PLAN §5.2, §8.3). `sealed`: a screen's `switch` must
/// show each case, and a new one breaks the build there.
sealed class AccountState {
  const AccountState();
}

/// The sign-in is on its way: « Créer » and « Rejoindre » wait for it.
final class AccountSigningIn extends AccountState {
  const AccountSigningIn();
}

/// The phone has its account: [member] can create or join a tournée.
final class AccountSignedIn extends AccountState {
  const AccountSignedIn(this.member);

  final MemberId member;

  @override
  bool operator ==(Object other) =>
      other is AccountSignedIn && other.member == member;

  @override
  int get hashCode => member.hashCode;

  @override
  String toString() => 'AccountSignedIn($member)';
}

/// The server could not be reached (« hors ligne »): the screen offers
/// « Réessayer ». Marking still works, the street screens need no account.
final class AccountOffline extends AccountState {
  const AccountOffline();
}
