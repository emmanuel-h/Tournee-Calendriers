import 'dart:async';

import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';

// The streets of M1 (« Mes rues », kept on the phone) go into the open
// tournée when the member asks (PLAN §5.0): the card « 12 rues sont
// enregistrées sur ce téléphone. [Les ajouter à la tournée] [Plus tard] ».

/// How many streets the phone still holds for the tournée [TourneeId]: the
/// card shows while it is above 0.
///
/// None once they went into that tournée ([MovedStreetsLog]), and none
/// unless the member is an active member of it as the phone last read it:
/// the tournée's rules refuse the streets of anyone else (PLAN §8.2).
/// Streets in the phone's Corbeille are not counted: they stay behind.
/// Works offline, from the phone's copy of the tournée.
final class CountStreetsToMove {
  const CountStreetsToMove(
    this._phoneStreets,
    this._log,
    this._tournees,
    this._identity,
  );

  final StreetRepository _phoneStreets;
  final MovedStreetsLog _log;
  final TourneeRepository _tournees;
  final IdentityProvider _identity;

  Future<int> call(TourneeId tournee) async {
    if (_log.wereMovedInto(tournee)) return 0;
    final team = await _tournees.find(tournee);
    final me = team?.memberOf(_identity.currentMember);
    if (me == null || !me.isActive) return 0;
    return (await _streetsNow(_phoneStreets)).length;
  }
}

/// What « Les ajouter à la tournée » did: « 10 rues ajoutées, 2 déjà dans
/// la tournée ».
final class StreetsMoved {
  const StreetsMoved({required this.moved, required this.alreadyThere});

  /// The streets added to the tournée.
  final int moved;

  /// The streets left out because the tournée already had them: the same
  /// BAN street (a teammate imported it), or the same street (moved
  /// before).
  final int alreadyThere;

  @override
  bool operator ==(Object other) =>
      other is StreetsMoved &&
      other.moved == moved &&
      other.alreadyThere == alreadyThere;

  @override
  int get hashCode => Object.hash(moved, alreadyThere);

  @override
  String toString() =>
      'StreetsMoved($moved moved, $alreadyThere already there)';
}

/// Adds the streets kept on the phone to the open tournée (« Les ajouter
/// à la tournée »), as the member using the phone, then remembers that
/// this tournée received them.
///
/// - Each street goes as it is — marks, buildings, « repasser » hints,
///   numbers in its Corbeille — with every stamp made by the member at
///   the time it had (`Street.restampedBy`): the tournée knows no phone
///   id, and its rules want the caller's uid (PLAN §8.2).
/// - A street the tournée already has (same BAN street, or the same
///   street) is skipped and counted, never duplicated: importing twice
///   must not wipe a teammate's marks.
/// - The streets of the phone's Corbeille stay behind, and the phone keeps
///   its copies (they are only no longer shown while a tournée is open).
/// - No network is needed to start: the tournée's storage keeps the new
///   streets on the phone and sends them when it can (PLAN §7). Started
///   again after an interruption, it skips what already went.
///
/// [_tourneeStreets] must be the streets of the tournée given to [call]:
/// the composition root binds the street storage to the open tournée.
final class MoveStreetsIntoTournee {
  const MoveStreetsIntoTournee(
    this._phoneStreets,
    this._tourneeStreets,
    this._identity,
    this._log,
  );

  final StreetRepository _phoneStreets;
  final StreetRepository _tourneeStreets;
  final IdentityProvider _identity;
  final MovedStreetsLog _log;

  /// Moves the streets into [tournee]. [onProgress] hears how many streets
  /// are done out of how many, before the first and after each one
  /// (« Ajout en cours… 3/12 »).
  Future<StreetsMoved> call(
    TourneeId tournee, {
    void Function(int done, int total)? onProgress,
  }) async {
    final streets = await _streetsNow(_phoneStreets);
    final member = _identity.currentMember;
    var moved = 0;
    var alreadyThere = 0;
    onProgress?.call(0, streets.length);
    for (final street in streets) {
      if (await _isInTournee(street)) {
        alreadyThere++;
      } else {
        await _tourneeStreets.add(street.restampedBy(member));
        moved++;
      }
      onProgress?.call(moved + alreadyThere, streets.length);
    }
    await _log.rememberMovedInto(tournee);
    return StreetsMoved(moved: moved, alreadyThere: alreadyThere);
  }

  Future<bool> _isInTournee(Street street) async {
    if (await _tourneeStreets.find(street.id) != null) return true;
    final banId = street.banId;
    return banId != null && await _tourneeStreets.findByBanId(banId) != null;
  }
}

/// The streets of [repository] not in the Corbeille, as they are now: the
/// first value of `watchAll`, after which the stream is left.
///
/// Not `Stream.first`, which also waits until the stream has finished
/// stopping: the street storages close their stream as they stop, which
/// the widget tests' fake clock never lets finish. The storages give their
/// values after `listen` returns, so `subscription` is set by then.
Future<List<Street>> _streetsNow(StreetRepository repository) {
  final now = Completer<List<Street>>();
  late final StreamSubscription<List<Street>> subscription;
  subscription = repository.watchAll().listen((streets) {
    now.complete(streets);
    unawaited(subscription.cancel());
  }, onError: now.completeError);
  return now.future;
}
