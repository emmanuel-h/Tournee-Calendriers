/// What the member chose about the reminders on this phone (PLAN §5.17,
/// §6.3): the switch « Rappels pour repasser », and whether Android's
/// permission was asked already. On the phone only.
///
/// An application port: the use cases own it, an adapter of
/// `infrastructure/local_storage/` implements it. Read without waiting:
/// the adapter loads the values before the first screen.
abstract interface class ReminderPreferences {
  /// « Rappels pour repasser »; on until the member turns it off.
  bool get on;

  /// Whether the app asked Android for the notification permission once.
  /// It asks the first time the member gives a « repasser » a day, never
  /// at launch.
  bool get permissionAsked;

  /// Keeps [on]. Answered by [on] at once; the returned `Future` ends once
  /// it is kept on the phone.
  Future<void> setOn(bool on);

  /// Keeps that the permission was asked, likewise.
  Future<void> markPermissionAsked();
}
