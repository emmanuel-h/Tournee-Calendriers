import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

// « Rejoindre une tournée » and « Demande envoyée » (PLAN §5.2): the
// tournée a code shows, the request to join it, and its cancellation.

/// The tournée whose join code is [JoinCode], from the server (« Tournée
/// 49 · CS Villefranche · Campagne 2026 »). Fails with
/// [JoinFailure.unknownCode] or [JoinFailure.noNetwork].
final class PreviewJoin {
  const PreviewJoin(this._directory);

  final TourneeDirectory _directory;

  Future<Result<JoinPreview, JoinFailure>> call(JoinCode code) =>
      _directory.preview(code);
}

/// Why « Demander à rejoindre » sent no request.
enum RequestToJoinFailure {
  /// The tournée is already one of the member's, joined or asked for.
  alreadyJoined,

  /// The phone could not reach the server for its first sign-in.
  noNetwork,
}

/// « Demander à rejoindre »: signs in when the phone has no account yet,
/// sends the request as [MemberName], and keeps the tournée on the phone as
/// a pending request (« Mes tournées », PLAN §5.3), which the app follows
/// until it is answered. Returns that pending tournée.
///
/// The request itself is queued like any write: once signed in, it is kept
/// on the phone at once and sent when the network allows.
final class RequestToJoin {
  const RequestToJoin(
    this._directory,
    this._account,
    this._myTournees,
    this._clock,
  );

  final TourneeDirectory _directory;
  final MemberAccount _account;
  final MyTourneesStore _myTournees;
  final Clock _clock;

  Future<Result<TourneeSummary, RequestToJoinFailure>> call(
    JoinPreview preview,
    MemberName name,
  ) async {
    // Asking again would turn an active member back into a request.
    if (_myTournees.myTournees.find(preview.tourneeId) != null) {
      return const Err(RequestToJoinFailure.alreadyJoined);
    }
    final MemberId member;
    switch (await _account.signInIfNeeded()) {
      case Ok(:final value):
        member = value;
      case Err(:final failure):
        return Err(switch (failure) {
          SignInFailure.noNetwork => RequestToJoinFailure.noNetwork,
        });
    }
    await _directory.requestToJoin(
      preview,
      Member(id: member, name: name, requestedAt: _clock.now()),
    );
    // What the preview showed: a pending newcomer cannot read the tournée.
    final request = TourneeSummary(
      id: preview.tourneeId,
      number: preview.number,
      centre: preview.centre,
      campaign: preview.campaign,
      status: MemberStatus.pending,
    );
    await _myTournees.save(_myTournees.myTournees.remember(request));
    return Ok(request);
  }
}

/// « Annuler la demande »: withdraws the member's request to join
/// [TourneeId] and forgets it on the phone. Works offline: the withdrawal
/// is sent when the network allows.
final class CancelJoinRequest {
  const CancelJoinRequest(this._directory, this._account, this._myTournees);

  final TourneeDirectory _directory;
  final MemberAccount _account;
  final MyTourneesStore _myTournees;

  Future<void> call(TourneeId tournee) async {
    // A phone that never signed in sent no request: only forget it.
    if (_account.signedInMember case final member?) {
      await _directory.cancelRequest(tournee, member);
    }
    await _myTournees.save(_myTournees.myTournees.forget(tournee));
  }
}
