// An in-memory MovedStreetsLog: no file, answers at once, and records each
// tournée remembered so tests can assert it.
import 'package:tournee_calendriers/application/ports/moved_streets_log.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

final class FakeMovedStreetsLog implements MovedStreetsLog {
  /// A phone whose streets already went into [tournees] (none by default).
  FakeMovedStreetsLog([Iterable<TourneeId> tournees = const []])
    : _tournees = {...tournees};

  final Set<TourneeId> _tournees;

  /// Every tournée given to [rememberMovedInto], in order.
  final remembered = <TourneeId>[];

  @override
  bool wereMovedInto(TourneeId tournee) => _tournees.contains(tournee);

  @override
  Future<void> rememberMovedInto(TourneeId tournee) async {
    remembered.add(tournee);
    _tournees.add(tournee);
  }
}
