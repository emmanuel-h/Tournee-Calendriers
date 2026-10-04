/// The time of the phone, as the use cases read it to stamp a change
/// (« Modifié par Léa · 14:02 »).
///
/// A port rather than `DateTime.now()`, so tests give a fixed time and
/// assert the exact stamp (PLAN §11: no real clock in tests).
abstract interface class Clock {
  /// The current time, in UTC. Storage keeps UTC; the screens show it in
  /// the phone's time zone.
  DateTime now();
}
