import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

// « Mes tournées » (PLAN §5.3, §6.3): the member's tournées on this phone,
// which one is open, what became of their requests to join, and whether
// they are still in each tournée. Everything but following a request or a
// membership works offline; offline, neither ever forgets a tournée.

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
      // Still waiting; and a request is never « visiting », which only the
      // phone's own summary of an admin's visit is.
      case MemberStatus.pending || MemberStatus.visiting:
        break;
    }
  }
}

/// Whether the member is still in [TourneeSummary], one of their tournées,
/// from the server (`TourneeDirectory.watchMembership`): tells once they
/// were removed or the tournée deleted, nothing otherwise.
///
/// A phone that never signed in cannot be in a tournée on the server:
/// nothing to follow then.
final class WatchMembership {
  const WatchMembership(this._directory, this._account);

  final TourneeDirectory _directory;
  final MemberAccount _account;

  Stream<TourneeLoss> call(TourneeSummary tournee) =>
      switch (_account.signedInMember) {
        final member? => _directory.watchMembership(tournee, member),
        null => const Stream.empty(),
      };
}

/// The first name the server holds for the member in [TourneeId], one of
/// their tournées (`TourneeDirectory.watchOwnName`), for
/// `CatchUpMemberName` to send the phone's name where it differs.
///
/// A name heard again just after itself is told once (`distinct`): if the
/// server refused the rename sent (and went back to the old name), the
/// phone does not send it again and again; it tries again at the next
/// launch or sign-in.
///
/// A phone that never signed in cannot be in a tournée on the server:
/// nothing to follow then.
final class WatchOwnName {
  const WatchOwnName(this._directory, this._account);

  final TourneeDirectory _directory;
  final MemberAccount _account;

  Stream<MemberName> call(TourneeId tournee) =>
      switch (_account.signedInMember) {
        final member? => _directory.watchOwnName(tournee, member).distinct(),
        null => const Stream.empty(),
      };
}

/// A tournée the phone forgot because the member lost it: [loss] tells
/// how, [wasOpen] whether it was the one the app showed (the app then goes
/// back to its start screen with none open).
final class LostTournee {
  const LostTournee({
    required this.tournee,
    required this.loss,
    required this.wasOpen,
  });

  /// The tournée as the phone kept it: « la tournée 49 ».
  final TourneeSummary tournee;
  final TourneeLoss loss;
  final bool wasOpen;

  @override
  bool operator ==(Object other) =>
      other is LostTournee &&
      other.tournee == tournee &&
      other.loss == loss &&
      other.wasOpen == wasOpen;

  @override
  int get hashCode => Object.hash(tournee, loss, wasOpen);

  @override
  String toString() =>
      'LostTournee(${tournee.id.value}, ${loss.name}, '
      '${wasOpen ? 'open' : 'closed'})';
}

/// Forgets the tournée [TourneeId] the member lost ([TourneeLoss]): it
/// leaves « Mes tournées » and, when it was open, none is open any more.
/// Returns what was forgotten, for the app to say it.
///
/// Returns null and changes nothing when the phone no longer knows the
/// tournée (it was left or deleted from this phone in the meantime: nothing
/// to tell) or knows it only as a request, which `SettleJoinRequest`
/// follows.
final class ForgetLostTournee {
  const ForgetLostTournee(this._store);

  final MyTourneesStore _store;

  Future<LostTournee?> call(TourneeId id, TourneeLoss loss) async {
    final mine = _store.myTournees;
    final tournee = mine.find(id);
    if (tournee == null || tournee.isPending) return null;
    await _store.save(mine.forget(id));
    return LostTournee(
      tournee: tournee,
      loss: loss,
      wasOpen: mine.currentId == id,
    );
  }
}
