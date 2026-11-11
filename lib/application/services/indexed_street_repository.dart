import 'package:tournee_calendriers/application/ports/street_part_index.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The open secteur's streets, keeping the shared index of who holds which
/// part of a street up to date (PLAN §5.15, §6.2 `streetParts/{banId}`).
///
/// **The one place in the app that reacts to a street's changes.** Every
/// [StreetChange] a use case saves passes through [save], whose exhaustive
/// `switch` says what each kind of change means for the index; nothing
/// else listens to changes (no event bus: at this size a decorator is
/// enough). A new reaction to a change belongs here.
///
/// A decorator: it is a [StreetRepository] itself, hands every call to
/// the [StreetRepository] it wraps, and after the writes that change what
/// the secteur holds of a street from the BAN, tells the [StreetPartIndex]:
///
/// - a street **added**, its **part changed**, or **restored** from the
///   Corbeille: the secteur holds its part ([StreetPartIndex.hold]);
/// - a street sent to the **Corbeille**, or **purged**: it holds none of
///   it ([StreetPartIndex.release]).
///
/// Every use case writes through it, so none of them can forget the index
/// (an undo of « Supprimer la rue » is a restore like the Corbeille's). A
/// street typed by hand has no BAN id and no entry. A street added before
/// the index existed gets its entry at its next such write (single user,
/// nothing migrated).
///
/// The street is written first, the index after. The two writes are not
/// atomic: the index write is not awaited (it ends only when the server
/// has it, hours later offline) but handed to [_report], which the app
/// binds to the reporter of every background write (`sendInBackground`).
/// A refused index write therefore never fails the street's, and is
/// still seen: logged as « index hold 69264_0420 » or « index release … »,
/// the index left behind until the street's next such write.
final class IndexedStreetRepository implements StreetRepository {
  /// [report] receives each index write, labelled, and watches how it
  /// ends; it must not throw.
  const IndexedStreetRepository(
    this._streets,
    this._index, {
    required this._report,
  });

  final StreetRepository _streets;
  final StreetPartIndex _index;
  final void Function(String what, Future<void> write) _report;

  @override
  Future<Street?> find(StreetId id) => _streets.find(id);

  @override
  Future<Street?> findByBanId(BanStreetId banId) => _streets.findByBanId(banId);

  @override
  Stream<Street?> watch(StreetId id) => _streets.watch(id);

  @override
  Stream<List<Street>> watchAll() => _streets.watchAll();

  @override
  Stream<List<Street>> watchDeleted() => _streets.watchDeleted();

  @override
  Future<void> add(Street street) async {
    await _streets.add(street);
    if (street.banId case final banId?) _hold(banId, street);
  }

  @override
  Future<void> save(Street street, StreetChange change) async {
    await _streets.save(street, change);
    final banId = street.banId;
    if (banId == null) return;
    // Exhaustive, without `default`: a new kind of change must say here
    // whether it changes what the secteur holds. True: it holds its part
    // now; false: none of it; null: nothing changed.
    final holds = switch (change) {
      StreetPartChanged() || StreetRestored() => true,
      StreetDeleted() => false,
      HouseChange() ||
      DwellingChange() ||
      StreetShapeFilled() ||
      NumbersAdded() ||
      NumberRemoved() ||
      NumberRestored() ||
      NumbersPurged() ||
      StreetRenamed() ||
      HouseReverted() ||
      DwellingReverted() => null,
    };
    switch (holds) {
      case true:
        _hold(banId, street);
      case false:
        _release(banId);
      case null:
    }
  }

  /// Purges the street, then releases its entry. Its BAN id is read first,
  /// from memory: the street is gone once purged. The purge is the 30-day
  /// clean-up of the Corbeille (`PurgeCorbeille`), which reads the street
  /// the same way just before, never a tap racing another.
  @override
  Future<void> purge(StreetId id) async {
    final banId = (await _streets.find(id))?.banId;
    await _streets.purge(id);
    if (banId != null) _release(banId);
  }

  void _hold(BanStreetId banId, Street street) =>
      _report('index hold ${banId.value}', _index.hold(banId, street.part));

  void _release(BanStreetId banId) =>
      _report('index release ${banId.value}', _index.release(banId));
}
