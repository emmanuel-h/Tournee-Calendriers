import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';

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
/// On this phone only: the member documents of their tournées keep the
/// name they joined with (PLAN §6.3).
final class ChangeMemberName {
  const ChangeMemberName(this._settings);

  final PhoneSettings _settings;

  Future<Result<MemberName, MemberNameFailure>> call(String text) async {
    final name = MemberName.create(text);
    if (name case Ok(:final value)) await _settings.setMemberName(value);
    return name;
  }
}

/// « Thème »: keeps the theme chosen.
final class ChooseTheme {
  const ChooseTheme(this._settings);

  final PhoneSettings _settings;

  Future<void> call(ThemeChoice theme) => _settings.setTheme(theme);
}
