/// Empties, at the app's next start, the copy of the server's data the
/// phone keeps for offline use (PLAN §6.3, §8.3), so that the streets of a
/// secteur the member no longer belongs to (left, removed, deleted, or no
/// longer an admin's to visit) leave the phone.
///
/// Not at once: the copy can only be emptied before the app first reads
/// it. The secteurs the member still holds come back with their next
/// download, which the app runs by itself (PLAN §7).
///
/// An application port: the use cases that forget a secteur own it, an
/// adapter of `infrastructure/firestore/` implements it, tests use a fake.
abstract interface class PhoneCacheReset {
  /// Asks for the copy to be emptied at a next start. Returns at once and
  /// never fails: the adapter records the request on the phone in the
  /// background, and empties nothing while changes made on this phone
  /// still wait to be sent (they would be lost with it).
  void scheduleAtNextStart();
}
