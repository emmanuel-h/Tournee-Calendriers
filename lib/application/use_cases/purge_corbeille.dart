import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// How much a purge removed: whole streets, and numbers of the streets
/// kept. A Dart record: a small value with named fields, compared by value.
typedef CorbeillePurged = ({int streets, int numbers});

/// The 30-day purge of the Corbeille (PLAN §5.11): removes for good the
/// streets and the numbers deleted more than 30 days before the clock's
/// time, with their marks.
///
/// There is no server to do it: each member's app runs it when it opens
/// the tournée's streets, and the first one online gets it done. The
/// others' purges of the same items change nothing, and the security rules
/// refuse any hard delete of an item removed 30 days ago or less, should a
/// phone's copy be out of date (a teammate restored it in the meantime).
///
/// Works offline as every street write does: the phone's copy changes at
/// once and the writes are sent when the network is back.
final class PurgeCorbeille {
  const PurgeCorbeille(this._streets, this._clock);

  final StreetRepository _streets;
  final Clock _clock;

  /// Purges what is past the 30 days and says how much went. Throws what
  /// the repository throws (the streets cannot be read or written).
  Future<CorbeillePurged> call() async {
    final now = _clock.now();
    // `.first`: the streets as they are now, then stop listening.
    final ids = <StreetId>[
      for (final street in await _streets.watchDeleted().first) street.id,
      for (final street in await _streets.watchAll().first) street.id,
    ];
    var streets = 0;
    var numbers = 0;
    for (final id in ids) {
      // Read again: a member may have changed the street while the purge
      // was busy with the others. `find` answers from memory and nothing
      // can run between it and the write (see `runOnStreet`).
      final street = await _streets.find(id);
      if (street == null) continue;
      // `if (… case (…))`: a record pattern, which matches only when
      // `purgeNumbers` gave a record (not null), and names its two parts.
      if (street.isPastRetention(now: now)) {
        await _streets.purge(id);
        streets++;
      } else if (street.purgeNumbers(now: now) case (
        final Street purged,
        final change,
      )) {
        await _streets.save(purged, change);
        numbers += change.purged.length;
      }
    }
    return (streets: streets, numbers: numbers);
  }
}
