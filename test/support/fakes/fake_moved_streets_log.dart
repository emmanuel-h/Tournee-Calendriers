// An in-memory MovedStreetsLog: no file, answers at once, and records each
// tournée remembered so tests can assert it.
import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

final class FakeMovedStreetsLog implements MovedStreetsLog {
  /// A phone whose streets already went into [sectors] (none by default).
  FakeMovedStreetsLog([Iterable<SectorId> sectors = const []])
    : _sectors = {...sectors};

  final Set<SectorId> _sectors;

  /// Every tournée given to [rememberMovedInto], in order.
  final remembered = <SectorId>[];

  @override
  bool wereMovedInto(SectorId sector) => _sectors.contains(sector);

  @override
  Future<void> rememberMovedInto(SectorId sector) async {
    remembered.add(sector);
    _sectors.add(sector);
  }
}
