import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';

/// What the join screen shows before the newcomer asks to join (« Tournée
/// 49 · CS Villefranche · Campagne 2026 », PLAN §5.2), read with the exact
/// [code] typed or scanned. Nothing else about the tournée is readable
/// before an active member accepts the request (PLAN §8.1).
final class JoinPreview {
  const JoinPreview({
    required this.code,
    required this.tourneeId,
    required this.number,
    required this.centre,
    required this.campaign,
  });

  /// The code that found the tournée; the request carries it, so the
  /// server can check it is still the tournée's code.
  final JoinCode code;

  final TourneeId tourneeId;
  final TourneeNumber number;
  final RescueCentre centre;

  /// The year being worked on.
  final CampaignYear campaign;

  @override
  bool operator ==(Object other) =>
      other is JoinPreview &&
      other.code == code &&
      other.tourneeId == tourneeId &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign;

  @override
  int get hashCode => Object.hash(code, tourneeId, number, centre, campaign);

  @override
  String toString() =>
      'JoinPreview(${code.display}, ${tourneeId.value}, ${number.value}, '
      '${centre.name}, ${campaign.value})';
}

/// Why a join code shows no tournée (« Rejoindre », PLAN §5.2).
enum JoinFailure {
  /// No tournée has this code: mistyped, or replaced by a new one (« Nouveau
  /// code »).
  unknownCode,

  /// The phone could not reach the server: joining needs the network
  /// (PLAN §7).
  noNetwork,
}

/// Why the directory could not answer.
enum DirectoryFailure {
  /// The phone could not reach the server: creating a tournée needs the
  /// network (PLAN §7).
  noNetwork,
}

/// What someone outside a tournée needs from the server: the newcomer who
/// joins with a code, the member who creates a tournée (PLAN Q20, §8.1).
///
/// An application port: the use cases own this interface, an adapter in
/// `infrastructure/` implements it with Firestore (a `joinCodes/{code}` get
/// and a pending member document, on the phone, PLAN §6.2). A server-side
/// join with rate limiting (a Cloud Function, PLAN Q20) would be another
/// adapter of this same port, with no change to the use cases.
///
/// `TourneeRepository` is for the members of a tournée; a pending newcomer
/// cannot read it (PLAN §8.2), hence this separate port.
///
/// Failures the user can act on are returned; a storage failure they
/// cannot act on is thrown.
abstract interface class TourneeDirectory {
  /// The tournée whose join code is [code], from the server.
  ///
  /// Fails with [JoinFailure.unknownCode] when no tournée has it and with
  /// [JoinFailure.noNetwork] offline.
  Future<Result<JoinPreview, JoinFailure>> preview(JoinCode code);

  /// Asks to join the tournée of [preview] (« Rejoindre »): stores
  /// [request], a pending member made by the newcomer, which any active
  /// member then accepts or refuses (PLAN §5.8). Returns once the request
  /// is on the phone; it reaches the server as soon as the network allows.
  /// [watchRequest] tells what became of it.
  ///
  /// Throws an [ArgumentError] when [request] is already accepted: only a
  /// pending request can be sent.
  Future<void> requestToJoin(JoinPreview preview, Member request);

  /// Where the request of [member] to join [tournee] stands, now and after
  /// each change: pending, then active once accepted (« Demande envoyée »
  /// then Accueil, PLAN §5.2). Null when there is no request any more:
  /// refused, cancelled, or refused by the server because the code changed
  /// in the meantime.
  Stream<MemberStatus?> watchRequest(TourneeId tournee, MemberId member);

  /// Cancels the pending request of [member] to join [tournee] (« Annuler
  /// la demande »). Applied on the phone at once, sent with the network.
  Future<void> cancelRequest(TourneeId tournee, MemberId member);

  /// Whether a tournée [number] already exists in [centre] (the same
  /// station, however written: `RescueCentre.isSameStationAs`), asked
  /// while the creator types (« La tournée 49 du CS Villefranche existe
  /// déjà », PLAN §5.2). Fails with [DirectoryFailure.noNetwork] offline.
  Future<Result<bool, DirectoryFailure>> isTaken(
    RescueCentre centre,
    TourneeNumber number,
  );

  /// The centres de secours already known to the app, for the creator to
  /// pick from (PLAN §5.2), one per station, by name. Fails with
  /// [DirectoryFailure.noNetwork] offline.
  Future<Result<List<RescueCentre>, DirectoryFailure>> rescueCentres();
}
