import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

// « Mes tournées » (PLAN §5.3, §6.3): the member's tournées on this phone,
// which one is open, and what became of their requests to join. Everything
// but following a request works offline.

/// The member's tournées as the phone keeps them. Synchronous: read once
/// at start-up, so the open tournée shows from the first frame.
final class ReadMyTournees {
  const ReadMyTournees(this._store);

  final MyTourneesStore _store;

  MyTournees call() => _store.myTournees;
}

/// Each new list of the member's tournées, whoever changed it.
final class ObserveMyTournees {
  const ObserveMyTournees(this._store);

  final MyTourneesStore _store;

  Stream<MyTournees> call() => _store.changes;
}

/// Opens the tournée [TourneeId] (a tap in « Mes tournées »): the app
/// shows it now and at the next launch. Returns it, or why it cannot be
/// opened.
final class OpenTournee {
  const OpenTournee(this._store);

  final MyTourneesStore _store;

  Future<Result<TourneeSummary, OpenTourneeFailure>> call(TourneeId id) async {
    final mine = _store.myTournees;
    switch (mine.open(id)) {
      case Ok(:final value):
        // Opening the open one again writes nothing.
        if (mine.currentId != id) await _store.save(value);
        return Ok(value.current!);
      case Err(:final failure):
        return Err(failure);
    }
  }
}

/// Where the member's request to join a tournée stands, from the server
/// (`TourneeDirectory.watchRequest`): pending, then active once accepted,
/// null once refused or cancelled.
///
/// A phone that never signed in cannot have sent a request (the server
/// lets in the account's uid only, PLAN §8.2): nothing to follow then.
final class WatchJoinRequest {
  const WatchJoinRequest(this._directory, this._account);

  final TourneeDirectory _directory;
  final MemberAccount _account;

  Stream<MemberStatus?> call(TourneeId tournee) =>
      switch (_account.signedInMember) {
        final member? => _directory.watchRequest(tournee, member),
        null => const Stream.empty(),
      };
}

/// Records what became of the member's request to join [TourneeId]:
/// accepted, it becomes one of their tournées (not opened: they choose
/// when); gone (refused, cancelled), the phone forgets it. A request still
/// pending, or a tournée that is not a request any more, changes nothing.
final class SettleJoinRequest {
  const SettleJoinRequest(this._store);

  final MyTourneesStore _store;

  Future<void> call(TourneeId id, MemberStatus? status) async {
    final mine = _store.myTournees;
    final request = mine.find(id);
    if (request == null || !request.isPending) return;
    switch (status) {
      case MemberStatus.active:
        await _store.save(mine.remember(request.accepted()));
      case null:
        await _store.save(mine.forget(id));
      case MemberStatus.pending:
        break;
    }
  }
}
