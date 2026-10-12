import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
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
      final tournee = await _tournees.find(summary.id);
      if (tournee == null) continue;
      if (tournee.rename(name, by: by) case Ok(
        value: (final renamed, final change),
      )) {
        await _tournees.save(renamed, change);
      }
    }
  }
}

/// « Thème »: keeps the theme chosen.
final class ChooseTheme {
  const ChooseTheme(this._settings);

  final PhoneSettings _settings;

  Future<void> call(ThemeChoice theme) => _settings.setTheme(theme);
}
