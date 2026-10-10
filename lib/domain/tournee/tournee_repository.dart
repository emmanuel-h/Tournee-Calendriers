import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// Why a new tournée could not be stored (« Créer », PLAN §5.2).
enum AddTourneeFailure {
  /// Another tournée already has this number in this centre de secours
  /// (same `RescueCentreKey`): ask its creator for the code instead.
  alreadyExists,

  /// The phone could not reach the server. Creating a tournée needs the
  /// network, since only the server knows whether the pair is taken
  /// (PLAN §7).
  noNetwork,
}

/// Why a change to a stored tournée that needs the server was not made
/// (« Nouveau code », « Supprimer la tournée », PLAN §5.8).
enum TourneeWriteFailure {
  /// The phone could not reach the server. A new code must be checked
  /// against every other tournée's, and deleting reads what the tournée
  /// holds from the server: neither can wait in a queue (PLAN §7).
  noNetwork,
}

/// Where the tournées the member belongs to are kept: Firestore from M2
/// (`tournees/{id}` and its `members`, PLAN §6.2). A repository port: the
/// domain owns this interface, an adapter in `infrastructure/` implements
/// it, and tests use an in-memory fake.
///
/// It takes and returns [Tournee] aggregates and [TourneeChange]s, never a
/// storage type. Only an active member can read a tournée (PLAN §8.2), so a
/// pending newcomer joins through another port (the join code lookup and
/// the request), not through this one.
///
/// Reads come from the phone's copy once the tournée has been seen, so the
/// team screen opens offline; accepting, refusing, removing and leaving are
/// applied on the phone at once and sent when the network is back. A
/// storage failure the user cannot act on is thrown as an exception;
/// [add], [save] and [delete] return the failures they can act on.
abstract interface class TourneeRepository {
  /// The tournée [id] as it is now; null when there is none, or when this
  /// member may no longer read it (removed, left).
  Future<Tournee?> find(TourneeId id);

  /// The tournée [id] now, then again after each change to it or to its
  /// members (a request arrives, a teammate accepts it), so Équipe follows
  /// the team live. Emits null while there is no such tournée or this
  /// member may not read it: a removed member's screens close.
  Stream<Tournee?> watch(TourneeId id);

  /// Stores [tournee], just created with `Tournee.createdBy`, with what
  /// makes it findable: its join code and the reservation of its number in
  /// its centre de secours, all or nothing.
  ///
  /// Fails with [AddTourneeFailure.alreadyExists] when the number is taken
  /// in that centre, even by someone creating it at the same second
  /// (PLAN §6.2), and with [AddTourneeFailure.noNetwork] offline.
  Future<Result<Tournee, AddTourneeFailure>> add(Tournee tournee);

  /// Stores [change], which turned the stored tournée into [tournee], and
  /// returns the tournée as stored.
  ///
  /// Both are given so the adapter writes only what [change] names (one
  /// member's document, the join code) and still finds what it needs
  /// around it (the preview fields of a new join code).
  ///
  /// A member accepted, refused, removed or leaving is kept on the phone at
  /// once and sent when the network is back: it never fails. A new join
  /// code needs the server, which checks no other tournée holds it: one
  /// that does is replaced by another (the stored tournée then has that
  /// one), and offline it fails with [TourneeWriteFailure.noNetwork].
  Future<Result<Tournee, TourneeWriteFailure>> save(
    Tournee tournee,
    TourneeChange change,
  );

  /// Deletes the tournée of [deletion] and everything in it: members,
  /// campaigns, streets, its join code and its number reservation. Returns
  /// [deletion] once done.
  ///
  /// Needs the server, which alone knows everything the tournée holds:
  /// offline it deletes nothing and fails with
  /// [TourneeWriteFailure.noNetwork].
  Future<Result<TourneeDeleted, TourneeWriteFailure>> delete(
    TourneeDeleted deletion,
  );
}
