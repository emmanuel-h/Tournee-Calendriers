import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/join_request.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// What the join screen shows before the newcomer asks to join (« Tournée
/// 49 · CS Villefranche · Campagne 2026 », PLAN §5.2), read with the exact
/// [code] typed or scanned. Nothing else about the tournée is readable
/// before an active member accepts the request (PLAN §8.1).
final class JoinPreview {
  const JoinPreview({
    required this.code,
    required this.sectorId,
    required this.number,
    required this.centre,
    required this.campaign,
  });

  /// The code that found the tournée; the request carries it, so the
  /// server can check it is still the tournée's code.
  final JoinCode code;

  final SectorId sectorId;
  final SectorNumber number;
  final RescueCentre centre;

  /// The year being worked on.
  final CampaignYear campaign;

  @override
  bool operator ==(Object other) =>
      other is JoinPreview &&
      other.code == code &&
      other.sectorId == sectorId &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign;

  @override
  int get hashCode => Object.hash(code, sectorId, number, centre, campaign);

  @override
  String toString() =>
      'JoinPreview(${code.display}, ${sectorId.value}, ${number.value}, '
      '${centre.name}, ${campaign.value})';
}

/// One tournée of the app as « Tous les secteurs » lists it for an admin
/// (PLAN §5.12): « Tournée 12 · 2026 » under its centre, « 3 membres · 1
/// demande en attente », « · vous en êtes membre ».
final class SectorOverview {
  const SectorOverview({
    required this.id,
    required this.number,
    required this.centre,
    required this.campaign,
    required this.activeMembers,
    required this.pendingRequests,
    required this.callerIsActive,
  });

  final SectorId id;
  final SectorNumber number;
  final RescueCentre centre;

  /// The year being worked on.
  final CampaignYear campaign;

  /// How many members are in the team (accepted); 0 once all left.
  final int activeMembers;

  /// How many requests to join wait for an answer.
  final int pendingRequests;

  /// Whether the admin asking is an active member of it.
  final bool callerIsActive;

  @override
  bool operator ==(Object other) =>
      other is SectorOverview &&
      other.id == id &&
      other.number == number &&
      other.centre == centre &&
      other.campaign == campaign &&
      other.activeMembers == activeMembers &&
      other.pendingRequests == pendingRequests &&
      other.callerIsActive == callerIsActive;

  @override
  int get hashCode => Object.hash(
    id,
    number,
    centre,
    campaign,
    activeMembers,
    pendingRequests,
    callerIsActive,
  );

  @override
  String toString() =>
      'SectorOverview(${id.value}, ${number.value}, ${centre.name}, '
      '${campaign.value}, $activeMembers active, $pendingRequests pending, '
      'caller ${callerIsActive ? 'in' : 'out'})';
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

  /// The server refused: only an admin lists every tournée
  /// ([SectorDirectory.allSectors]), and the member on the phone is no
  /// longer one (PLAN §5.12).
  notAdmin,
}

/// What someone outside a tournée needs from the server: the newcomer who
/// joins with a code, the admin who creates a tournée or looks at all of
/// them (PLAN Q20, §8.1, §5.12).
///
/// An application port: the use cases own this interface, an adapter in
/// `infrastructure/` implements it with Firestore (a `joinCodes/{code}` get
/// and a pending member document, on the phone, PLAN §6.2). A server-side
/// join with rate limiting (a Cloud Function, PLAN Q20) would be another
/// adapter of this same port, with no change to the use cases.
///
/// `SectorRepository` is for the members of a tournée; a pending newcomer
/// cannot read it (PLAN §8.2), hence this separate port.
///
/// Failures the user can act on are returned; a storage failure they
/// cannot act on is thrown.
abstract interface class SectorDirectory {
  /// The tournée whose join code is [code], from the server.
  ///
  /// Fails with [JoinFailure.unknownCode] when no tournée has it and with
  /// [JoinFailure.noNetwork] offline.
  Future<Result<JoinPreview, JoinFailure>> preview(JoinCode code);

  /// Asks to join a tournée (« Rejoindre »): stores [request], whose
  /// pending member any active member then accepts or refuses (PLAN §5.8).
  /// Returns once the request is on the phone; it reaches the server as
  /// soon as the network allows. [watchRequest] tells what became of it.
  Future<void> requestToJoin(JoinRequest request);

  /// Where the request of [member] to join [sector] stands, now and after
  /// each change: pending, then active once accepted (« Demande envoyée »
  /// then Accueil, PLAN §5.2). Null when there is no request any more:
  /// refused, cancelled, or refused by the server because the code changed
  /// in the meantime.
  Stream<MemberStatus?> watchRequest(SectorId sector, MemberId member);

  /// Cancels the pending request of [member] to join [sector] (« Annuler
  /// la demande »). Applied on the phone at once, sent with the network.
  Future<void> cancelRequest(SectorId sector, MemberId member);

  /// Tells once the server says [member] is no longer in [sector], one of
  /// their tournées (PLAN §5.3): [SectorLoss.removed] while the tournée
  /// goes on without them, [SectorLoss.deleted] once it is gone.
  ///
  /// For a tournée the member only visits as an admin (PLAN §5.12, its
  /// status `visiting`), whether they may still see it:
  /// [SectorLoss.deleted] once it is gone, [SectorLoss.adminRevoked]
  /// once they are no longer an admin.
  ///
  /// Only the server's answer counts: the phone's copy alone (offline, or
  /// a tournée never read on this phone) never says a tournée is lost, so
  /// an offline phone keeps all its tournées (PLAN §7). Neither does a
  /// change made on this phone (leaving, deleting), which the use cases
  /// settle themselves. Emits nothing while the member is in.
  Stream<SectorLoss> watchMembership(SectorSummary sector, MemberId member);

  /// The first name the server holds for [member] in [sector], now and
  /// after each change, while they are active in it (PLAN §5.9): what
  /// Équipe shows the team. Cleaned as `MemberName` cleans it.
  ///
  /// Only the server's answer counts: nothing is told offline, while the
  /// request still waits, or while a rename made on this phone is not yet
  /// sent. Lets the phone send its current name where the team still
  /// sees another one.
  Stream<MemberName> watchOwnName(SectorId sector, MemberId member);

  /// Whether a tournée [number] already exists in [centre] (the same
  /// station, however written: `RescueCentre.isSameStationAs`), asked
  /// while the creator types (« La tournée 49 du CS Villefranche existe
  /// déjà », PLAN §5.2). Fails with [DirectoryFailure.noNetwork] offline.
  Future<Result<bool, DirectoryFailure>> isTaken(
    RescueCentre centre,
    SectorNumber number,
  );

  /// The centres de secours already known to the app, for the admin to
  /// pick from (PLAN §5.2), one per station, by name. Fails with
  /// [DirectoryFailure.noNetwork] offline.
  Future<Result<List<RescueCentre>, DirectoryFailure>> rescueCentres();

  /// Every tournée of the app, for an admin (« Tous les secteurs », PLAN
  /// §5.12), in no particular order; [caller] is the admin asking, to tell
  /// the tournées they are an active member of. Asked of the server, never
  /// answered from the phone's copy, which may miss tournées: fails with
  /// [DirectoryFailure.noNetwork] offline, and with
  /// [DirectoryFailure.notAdmin] when the server says [caller] is not an
  /// admin.
  Future<Result<List<SectorOverview>, DirectoryFailure>> allSectors(
    MemberId caller,
  );
}
