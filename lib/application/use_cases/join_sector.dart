import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

// « Rejoindre un secteur » and « Demande envoyée » (PLAN §5.2): the
// tournée a code shows, the request to join it, and its cancellation.

/// The tournée whose join code is [JoinCode], from the server (« Tournée
/// 49 · CS Villefranche · Campagne 2026 »). Fails with
/// [JoinFailure.unknownCode] or [JoinFailure.noNetwork].
final class PreviewJoin {
  const PreviewJoin(this._directory);

  final SectorDirectory _directory;

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
/// a pending request (« Mes secteurs », PLAN §5.3), which the app follows
/// until it is answered. Returns that pending tournée.
///
/// The request itself is queued like any write: once signed in, it is kept
/// on the phone at once and sent when the network allows.
final class RequestToJoin {
  const RequestToJoin(
    this._directory,
    this._account,
    this._mySectors,
    this._clock,
  );

  final SectorDirectory _directory;
  final MemberAccount _account;
  final MySectorsStore _mySectors;
  final Clock _clock;

  Future<Result<SectorSummary, RequestToJoinFailure>> call(
    JoinPreview preview,
    MemberName name,
  ) async {
    // Asking again would turn an active member back into a request.
    if (_mySectors.mySectors.find(preview.sectorId) != null) {
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
    final request = SectorSummary(
      id: preview.sectorId,
      number: preview.number,
      centre: preview.centre,
      campaign: preview.campaign,
      status: MemberStatus.pending,
    );
    await _mySectors.save(_mySectors.mySectors.remember(request));
    return Ok(request);
  }
}

/// « Annuler la demande »: withdraws the member's request to join
/// [SectorId] and forgets it on the phone. Works offline: the withdrawal
/// is sent when the network allows.
final class CancelJoinRequest {
  const CancelJoinRequest(this._directory, this._account, this._mySectors);

  final SectorDirectory _directory;
  final MemberAccount _account;
  final MySectorsStore _mySectors;

  Future<void> call(SectorId sector) async {
    // A phone that never signed in sent no request: only forget it.
    if (_account.signedInMember case final member?) {
      await _directory.cancelRequest(sector, member);
    }
    await _mySectors.save(_mySectors.mySectors.forget(sector));
  }
}
