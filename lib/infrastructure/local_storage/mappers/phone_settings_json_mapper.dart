// Translation between the settings of Paramètres (PLAN §5.9, §6.3) and the
// JSON the phone keeps for them. Pure functions: no file here, so they are
// tested alone.
//
// The schema, version 1:
//
//   { version: 1, name: "Manu" | null, theme: "system" | "light" | "dark" }
//
// Themes under fixed names, so renaming the Dart enum never changes what
// is on the phone. The name goes through `MemberName.create`.
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';

/// The schema version this code writes and reads.
const storedPhoneSettingsVersion = 1;

const _system = 'system';
const _light = 'light';
const _dark = 'dark';

/// The stored form of the member's [name] and [theme].
Map<String, Object?> phoneSettingsToJson({
  required MemberName? name,
  required ThemeChoice theme,
}) => {
  'version': storedPhoneSettingsVersion,
  'name': name?.text,
  'theme': switch (theme) {
    ThemeChoice.system => _system,
    ThemeChoice.light => _light,
    ThemeChoice.dark => _dark,
  },
};

/// The name and the theme read from [json] as `jsonDecode` gives it.
/// Throws a [FormatException] when it is not a version 1 file or the name
/// is not one `MemberName` takes.
({MemberName? name, ThemeChoice theme}) phoneSettingsFromJson(Object? json) {
  if (json case {
    'version': storedPhoneSettingsVersion,
    'name': final String? name,
    'theme': final String theme,
  }) {
    return (
      name: name == null
          ? null
          : switch (MemberName.create(name)) {
              Ok(:final value) => value,
              Err(:final failure) => throw FormatException(
                'Not a name ($failure): $name',
              ),
            },
      theme: switch (theme) {
        _system => ThemeChoice.system,
        _light => ThemeChoice.light,
        _dark => ThemeChoice.dark,
        _ => throw FormatException('Not a theme: $theme'),
      },
    );
  }
  throw FormatException('Not the phone settings: $json');
}
