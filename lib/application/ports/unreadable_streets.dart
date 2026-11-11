import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';

/// The streets of the open secteur whose stored data cannot be read
/// (PLAN §5.16, #149): listed on Accueil rather than left out, and deleted
/// by an admin.
///
/// An application port: the use cases own it, the Firestore street adapter
/// implements it from the same listener as the streets, so it works
/// offline as they do (PLAN §7). Apart from `StreetRepository`, which only
/// ever holds streets that read.
abstract interface class UnreadableStreets {
  /// Every street of the secteur that cannot be read, now and after each
  /// change, in no particular order; none while every street reads.
  Stream<List<UnreadableStreet>> watchUnreadable();

  /// Deletes the street [id] for good, as its document stands: nothing of
  /// it can be read, so nothing is kept. Memory first: it is gone from
  /// [watchUnreadable] before the first wait, and the deletion is sent
  /// when the network allows. Only an admin may (the security rules refuse
  /// anyone else, and the street then comes back).
  Future<void> delete(StreetId id);
}
