import 'package:tournee_calendriers/application/ports/unreadable_streets.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';

// The streets whose stored data cannot be read (PLAN §5.16, #149): a row of
// their own on Accueil, and a way for an admin to delete them.

/// The unreadable streets of the open secteur, now and after each change.
/// Works offline: they come from the phone's copy, as the streets do.
final class ObserveUnreadableStreets {
  const ObserveUnreadableStreets(this._streets);

  final UnreadableStreets _streets;

  Stream<List<UnreadableStreet>> call() => _streets.watchUnreadable();
}

/// « Supprimer la rue » on an unreadable street: deletes it for the whole
/// team, so that it can be added again. Shown to admins only; the security
/// rules refuse anyone else. Offline, the deletion waits for the network.
final class DeleteUnreadableStreet {
  const DeleteUnreadableStreet(this._streets);

  final UnreadableStreets _streets;

  Future<void> call(StreetId street) => _streets.delete(street);
}
