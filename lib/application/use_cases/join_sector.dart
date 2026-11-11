import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/join_request.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

// « Rejoindre un secteur » and « Demande envoyée » (PLAN §5.2): the
// secteur a code shows, the request to join it, and its cancellation.

/// The secteur whose join code is [JoinCode], from the server (« Secteur
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
  /// The secteur is already one of the member's, joined or asked for.
  alreadyJoined,

  /// The phone could not reach the server, for its first sign-in or for
  /// the request.
  noNetwork,

  /// A member of the secteur holds the name, case and accents ignored
  /// (#148, PLAN §5.16): ask again under another name for this secteur.
  nameTaken,

  /// The code no longer opens the secteur (a new code was drawn, or it
  /// was deleted, since it was shown).
  unknownCode,
}

/// « Demander à rejoindre »: signs in when the phone has no account yet,
/// sends the request as [MemberName] (the phone's prénom, or the name
/// chosen for this secteur when the prénom was taken there, PLAN §5.16),
/// and keeps the secteur on the phone as a pending request (« Mes
/// secteurs », PLAN §5.3) with that name, which the app follows until it
/// is answered. Returns that pending secteur.
///
/// Needs the server, which alone tells whether the name is free in the
/// secteur: nothing is kept on the phone when it refuses or cannot be
/// reached.
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
    // Built by the domain, not here: the newcomer cannot read the secteur,
    // so no `Sector` root can make this member (PLAN §10.1).
    final sent = await _directory.requestToJoin(
      JoinRequest(
        sector: preview.sectorId,
        code: preview.code,
        by: member,
        name: name,
        at: _clock.now(),
      ),
    );
    if (sent case Err(:final failure)) {
      return Err(switch (failure) {
        JoinRequestFailure.nameTaken => RequestToJoinFailure.nameTaken,
        JoinRequestFailure.unknownCode => RequestToJoinFailure.unknownCode,
        JoinRequestFailure.noNetwork => RequestToJoinFailure.noNetwork,
      });
    }
    // What the preview showed: a pending newcomer cannot read the secteur.
    final request = SectorSummary(
      id: preview.sectorId,
      number: preview.number,
      centre: preview.centre,
      campaign: preview.campaign,
      status: MemberStatus.pending,
      memberName: name,
    );
    await _mySectors.save(_mySectors.mySectors.remember(request));
    return Ok(request);
  }
}

/// « Annuler la demande »: withdraws the member's request to join
/// [SectorId], freeing the name it held there (#148), and forgets it on
/// the phone. Works offline: the withdrawal is sent when the network
/// allows.
final class CancelJoinRequest {
  const CancelJoinRequest(this._directory, this._account, this._mySectors);

  final SectorDirectory _directory;
  final MemberAccount _account;
  final MySectorsStore _mySectors;

  Future<void> call(SectorId sector) async {
    // A phone that never signed in sent no request: only forget it.
    if (_account.signedInMember case final member?) {
      final name = _mySectors.mySectors.find(sector)?.memberName;
      await _directory.cancelRequest(sector, member, name);
    }
    await _mySectors.save(_mySectors.mySectors.forget(sector));
  }
}
