import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The new streets of one campaign whose writes to Firestore are not all
/// handed to it yet, kept on the phone so that a street cut off by a kill
/// of the app is finished at the next start (#104, PLAN §8.2 « Killed in
/// the middle »).
///
/// A port of the Firestore adapter, not of the application: only
/// `FirestoreStreetRepository` writes a street a few houses at a time (the
/// security rules check each house, #70), so only it needs to know. An
/// adapter of `infrastructure/local_storage/` keeps each street in a file;
/// tests use a fake.
///
/// No network, ever: the catch-up must work after an offline cold start.
abstract interface class UnfinishedStreets {
  /// The streets kept and not forgotten since, whole, as they were added.
  /// Empty when there is none, or when none can be read.
  Future<List<Street>> load();

  /// Keeps [street] whole, before its first write. The `Future` ends once
  /// it is on the phone: a kill after that cannot lose it.
  Future<void> keep(Street street);

  /// Forgets the street [id], once every write of it is in Firestore's
  /// hands (which keeps them across a restart). Nothing happens when it is
  /// not kept.
  Future<void> forget(StreetId id);
}
