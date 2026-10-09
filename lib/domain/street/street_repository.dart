import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// Where the streets of the tournée are kept: on the phone in M1, in
/// Firestore from M2 (PLAN §6.1, §6.2). A repository port: the domain owns
/// this interface, an adapter in `infrastructure/` implements it, and tests
/// use an in-memory fake.
///
/// It takes and returns [Street] aggregates and [StreetChange]s, never a
/// storage type. Everything here works without the network once the streets
/// are on the phone (PLAN §7): reads come from the phone, writes are applied
/// on the phone at once and, from M2, sent when the network is back.
///
/// A storage failure (a full disk) is not something the user can act on in
/// the street, so it is thrown as an exception, not returned as a failure.
///
/// **Memory first**, which every adapter must keep: [find] answers from
/// memory, and [add] and [save] put the new street in memory before they
/// first wait (for the disk, the network). Two quick taps then never lose
/// one another: the second reads the street the first one made (see
/// `runOnStreet`). Firestore's local cache works this way too: a write is
/// applied to the cache at once and sent later.
abstract interface class StreetRepository {
  /// The street [id] as it is now, in the Corbeille or not; null when there
  /// is none.
  Future<Street?> find(StreetId id);

  /// The street already imported from the BAN street [banId], in the
  /// Corbeille or not; null when none was. Importing twice must not create a
  /// second street (nor wipe the marks of the first).
  Future<Street?> findByBanId(BanStreetId banId);

  /// The street [id] now, then again after each change to it, so a screen
  /// follows the marks of the whole team live. Emits null while there is no
  /// such street.
  ///
  /// A `Stream` is a sequence of values over time: the screen listens to it
  /// and redraws each time a new street arrives.
  Stream<Street?> watch(StreetId id);

  /// Every street that is not in the Corbeille, now and after each change
  /// to any of them, in no particular order.
  Stream<List<Street>> watchAll();

  /// Every street in the Corbeille (« Corbeille », PLAN §5.11), now and
  /// after each change to any street, in no particular order. The numbers
  /// removed from the other streets are in their `removedHouses`.
  Stream<List<Street>> watchDeleted();

  /// Stores [street], new to the tournée (imported from the BAN, typed in by
  /// hand). It replaces nothing: the street id is new.
  Future<void> add(Street street);

  /// Stores [change], which turned the stored street into [street].
  ///
  /// Both are given so each adapter writes what suits it: the phone storage
  /// of M1 saves the whole [street]; Firestore writes only the fields
  /// [change] names (`houses.12.status`), so two people marking different
  /// houses never overwrite each other (PLAN §6.2).
  Future<void> save(Street street, StreetChange change);
}
