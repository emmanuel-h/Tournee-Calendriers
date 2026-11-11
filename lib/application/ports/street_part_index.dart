import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

/// Which secteur holds which part of a BAN street, shared by every secteur
/// (PLAN §5.15 « Other secteurs », §6.2 `streetParts/{banId}`): one entry
/// per secteur holding some of the street, so « Partie de la rue » and
/// « Ajouter des rues » can say « Secteur 12 : impairs 19–41 ».
///
/// An application port bound to the open secteur: the Firestore index of
/// the app, a fake in tests. The open secteur only ever writes its own
/// entry.
///
/// It never stands in the user's way: a write is handed over at once and
/// sent when the network allows, like any street write, and a read that
/// fails (offline, refused) gives nothing, so nothing is shown and
/// nothing is blocked. Nothing on the marking path uses it.
abstract interface class StreetPartIndex {
  /// Says the open secteur holds [part] of the BAN street [street]: a
  /// street added, its part changed, or restored from the Corbeille.
  ///
  /// The returned `Future` ends once the write is in the index's hands
  /// (queued on the phone), not when the server has it.
  Future<void> hold(BanStreetId street, StreetPart part);

  /// Says the open secteur no longer holds any of the BAN street
  /// [street]: sent to the Corbeille, or purged. Nothing changes when it
  /// held none. Handed over as [hold].
  Future<void> release(BanStreetId street);

  /// What the other secteurs hold of the BAN street [street], the open
  /// secteur left out, in no particular order; none when no other secteur
  /// holds any, and none when the index cannot be read (offline and never
  /// read, refused, unreadable).
  Future<List<SectorPart>> othersOf(BanStreetId street);
}
