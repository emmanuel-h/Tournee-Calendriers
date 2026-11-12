// Translation between the reminder preferences (PLAN §5.17, §6.3) and the
// JSON the phone keeps for them. Pure functions: no file here, so they are
// tested alone.
//
// The schema, version 1:
//
//   { version: 1, on: true | false, permissionAsked: true | false }

/// The schema version this code writes and reads.
const storedReminderPreferencesVersion = 1;

/// The stored form of the switch [on] and whether the permission was
/// asked ([permissionAsked]).
Map<String, Object?> reminderPreferencesToJson({
  required bool on,
  required bool permissionAsked,
}) => {
  'version': storedReminderPreferencesVersion,
  'on': on,
  'permissionAsked': permissionAsked,
};

/// The switch and whether the permission was asked, read from [json] as
/// `jsonDecode` gives it. Throws a [FormatException] when it is not a
/// version 1 file.
({bool on, bool permissionAsked}) reminderPreferencesFromJson(Object? json) {
  if (json case {
    'version': storedReminderPreferencesVersion,
    'on': final bool on,
    'permissionAsked': final bool permissionAsked,
  }) {
    return (on: on, permissionAsked: permissionAsked);
  }
  throw FormatException('Not reminder preferences: $json');
}
