import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a new secteur could not be stored (« Créer », PLAN §5.2).
enum AddSectorFailure {
  /// Another secteur already has this number in this centre de secours
  /// (same `RescueCentreKey`): ask its creator for the code instead.
  alreadyExists,

  /// The phone could not reach the server. Creating a secteur needs the
  /// network, since only the server knows whether the pair is taken
  /// (PLAN §7).
  noNetwork,

  /// The server refused: only an admin creates a secteur, and the member
  /// on the phone is no longer one (their `admins/{uid}` was removed while
  /// the phone still showed « Créer », PLAN §5.12).
  notAdmin,
}

/// Why a change to a stored secteur that needs the server was not made
/// (« Nouveau code », « Supprimer le secteur », a rename, an admin joining,
/// PLAN §5.8, §5.16).
enum SectorWriteFailure {
  /// The phone could not reach the server. A new code must be checked
  /// against every other secteur's, a name against every member's (#148),
  /// and deleting reads what the secteur holds from the server: none can
  /// wait in a queue (PLAN §7).
  noNetwork,

  /// The server refused: a new code, an admin joining and deleting are an
  /// admin's, and the member on the phone is no longer one (PLAN §5.12).
  notAdmin,

  /// Another member of the secteur holds the name, case and accents
  /// ignored (`MemberName.key`), which the phone's copy did not show yet
  /// (#148). Nothing was changed.
  nameTaken,
}

/// Where the secteurs the member belongs to are kept: Firestore
/// (`sectors/{id}` and its `members`, PLAN §6.2). A repository port: the
/// domain owns this interface, an adapter in `infrastructure/` implements
/// it, and tests use an in-memory fake.
///
/// It takes and returns [Sector] aggregates and [SectorChange]s, never a
/// storage type. Only an active member can read a secteur (PLAN §8.2), so a
/// pending newcomer joins through another port (the join code lookup and
/// the request), not through this one.
///
/// Reads come from the phone's copy once the secteur has been seen, so the
/// team screen opens offline; accepting, refusing, removing and leaving
/// are applied on the phone at once and sent when the network is back. A storage failure the user cannot act on is thrown as an exception;
/// [add], [save] and [delete] return the failures they can act on.
abstract interface class SectorRepository {
  /// The secteur [id] as it is now; null when there is none, or when this
  /// member may no longer read it (removed, left).
  Future<Sector?> find(SectorId id);

  /// The secteur [id] now, then again after each change to it or to its
  /// members (a request arrives, a teammate accepts it), so Équipe follows
  /// the team live. Emits null while there is no such secteur or this
  /// member may not read it: a removed member's screens close.
  Stream<Sector?> watch(SectorId id);

  /// Stores [sector], just created with `Sector.createdBy`, with what
  /// makes it findable: its join code and the reservation of its number in
  /// its centre de secours, and its creator's name held in it (#148), all
  /// or nothing.
  ///
  /// Fails with [AddSectorFailure.alreadyExists] when the number is taken
  /// in that centre, even by someone creating it at the same second
  /// (PLAN §6.2), with [AddSectorFailure.noNetwork] offline, and with
  /// [AddSectorFailure.notAdmin] when the server says the creator is not
  /// an admin.
  Future<Result<Sector, AddSectorFailure>> add(Sector sector);

  /// Stores [change], which turned the stored secteur into [sector], and
  /// returns the secteur as stored.
  ///
  /// Both are given so the adapter writes only what [change] names (one
  /// member's document, the join code) and still finds what it needs
  /// around it (the preview fields of a new join code).
  ///
  /// A member accepted, refused, removed or leaving is kept on the phone
  /// at once and sent when the network is back: it never fails; the name
  /// a member refused, removed or leaving held is freed with them (#148).
  /// A new join code needs the server, which checks no other secteur holds
  /// it: one that does is replaced by another (the stored secteur then has
  /// that one). A member renamed or an admin joining needs the server too,
  /// which checks no other member holds the name: one that does fails with
  /// [SectorWriteFailure.nameTaken], the old name then kept. Offline these
  /// fail with [SectorWriteFailure.noNetwork]. A new code or an admin
  /// joining fails with [SectorWriteFailure.notAdmin] when the server says
  /// the member is not an admin.
  Future<Result<Sector, SectorWriteFailure>> save(
    Sector sector,
    SectorChange change,
  );

  /// Deletes the secteur of [deletion] and everything in it: members and
  /// their names, campaigns, streets, its join code and its number
  /// reservation. Returns
  /// [deletion] once done.
  ///
  /// Needs the server, which alone knows everything the secteur holds:
  /// offline it deletes nothing and fails with
  /// [SectorWriteFailure.noNetwork]. It fails with
  /// [SectorWriteFailure.notAdmin], deleting nothing, when the server says
  /// the member is not an admin.
  Future<Result<SectorDeleted, SectorWriteFailure>> delete(
    SectorDeleted deletion,
  );
}
