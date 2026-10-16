import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';

// Paramètres (PLAN §5.9): the member's first name and the app's theme, kept
// on the phone (PLAN §6.3). Offline, always.

/// The name and the theme the member set. Synchronous: read once at
/// start-up, so the app opens in the chosen theme.
final class ReadPhoneSettings {
  const ReadPhoneSettings(this._settings);

  final PhoneSettings _settings;

  ({MemberName? name, ThemeChoice theme}) call() =>
      (name: _settings.memberName, theme: _settings.theme);
}

/// « Prénom »: keeps the typed text as the member's name once cleaned, or
/// says why it cannot be a name.
///
/// The name is kept on the phone (PLAN §6.3), then given to the member in
/// each tournée of « Mes tournées » they are active in, so Équipe shows the
/// new name to the team. Works offline: the tournées are read from the
/// phone's copy and storage sends the renames when the network is back.
/// A tournée the phone cannot read (removed, never opened offline) or that
/// refuses the rename (the member left meanwhile) is skipped: the name is
/// still kept on the phone.
final class ChangeMemberName {
  const ChangeMemberName(
    this._settings,
    this._tournees,
    this._identity,
    this._myTournees,
  );

  final PhoneSettings _settings;
  final TourneeRepository _tournees;
  final IdentityProvider _identity;
  final MyTourneesStore _myTournees;

  Future<Result<MemberName, MemberNameFailure>> call(String text) async {
    final name = MemberName.create(text);
    if (name case Ok(:final value)) {
      await _settings.setMemberName(value);
      await _renameInMyTournees(value);
    }
    return name;
  }

  Future<void> _renameInMyTournees(MemberName name) async {
    final by = _identity.currentMember;
    for (final summary in _myTournees.myTournees.tournees) {
      // A pending request cannot read its tournée (PLAN §8.2): nothing to
      // ask for.
      if (summary.isPending) continue;
      await _renameIn(_tournees, summary.id, name, by: by);
    }
  }
}

/// Catches up the member's name in [TourneeId], one of their tournées,
/// when the server holds another one than the phone's (`WatchOwnName`):
/// sends the phone's name with the same rename as « Prénom ».
///
/// Covers what [ChangeMemberName] could not reach: a rename made while
/// the request to join waited (PLAN §8.2: a pending member cannot rename
/// themself), sent once accepted, and a tournée the phone could not read
/// offline at the rename, sent once the server is heard again.
///
/// Both names are cleaned `MemberName`s, so equal names send nothing: the
/// rename the server then echoes back stops there. A phone without a name
/// yet, a tournée it cannot read or that refuses the rename (the member
/// left meanwhile) send nothing either.
final class CatchUpMemberName {
  const CatchUpMemberName(this._settings, this._tournees, this._identity);

  final PhoneSettings _settings;
  final TourneeRepository _tournees;
  final IdentityProvider _identity;

  Future<void> call(TourneeId tournee, MemberName heard) async {
    final mine = _settings.memberName;
    if (mine == null || mine == heard) return;
    await _renameIn(_tournees, tournee, mine, by: _identity.currentMember);
  }
}

/// Renames [by] to [name] in the tournée [id]; skips a tournée that cannot
/// be read or refuses the rename.
Future<void> _renameIn(
  TourneeRepository tournees,
  TourneeId id,
  MemberName name, {
  required MemberId by,
}) async {
  final tournee = await tournees.find(id);
  if (tournee == null) return;
  if (tournee.rename(name, by: by) case Ok(
    value: (final renamed, final change),
  )) {
    await tournees.save(renamed, change);
  }
}

/// « Thème »: keeps the theme chosen.
final class ChooseTheme {
  const ChooseTheme(this._settings);

  final PhoneSettings _settings;

  Future<void> call(ThemeChoice theme) => _settings.setTheme(theme);
}
