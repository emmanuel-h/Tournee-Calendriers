import 'dart:io';

import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/phone_settings_json_mapper.dart';

/// The [PhoneSettings] of the phone: `settings.json` in the storage folder
/// (PLAN §6.3), read once at start-up and then answered from memory. No
/// network, ever.
final class LocalPhoneSettings implements PhoneSettings {
  LocalPhoneSettings._(this._file, this.memberName, this.theme);

  /// Reads the settings kept in [file]. A missing or unreadable file means
  /// no name and the phone's theme: the next change writes the file again.
  static Future<LocalPhoneSettings> load(File file) async {
    final stored = JsonFile(file);
    MemberName? name;
    var theme = ThemeChoice.system;
    try {
      if (await stored.read() case final json?) {
        (:name, :theme) = phoneSettingsFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: start afresh.
    }
    return LocalPhoneSettings._(stored, name, theme);
  }

  final JsonFile _file;

  @override
  MemberName? memberName;

  @override
  ThemeChoice theme;

  @override
  Future<void> setMemberName(MemberName name) {
    memberName = name;
    return _write();
  }

  @override
  Future<void> setTheme(ThemeChoice theme) {
    this.theme = theme;
    return _write();
  }

  Future<void> _write() =>
      _file.write(phoneSettingsToJson(name: memberName, theme: theme));
}
