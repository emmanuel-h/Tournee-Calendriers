import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';

/// Why a command of Équipe was not done, as the screen tells it.
enum TeamActionFailure {
  /// The team changed in the meantime (a teammate answered the request
  /// first, the member was removed): the screen already shows it as it is.
  teamChanged,

  /// A new code, joining as an admin and deleting the tournée need the
  /// network.
  offline,

  /// Joining as an admin needs a first name, and the phone has none.
  noName,

  /// A command of an admin (« Nouveau code », « Retirer », « Supprimer la
  /// tournée », « Rejoindre ») from a phone no longer an admin's: the
  /// server refused it, or the phone learnt it just before (« Vous n'êtes
  /// plus administrateur. »).
  notAdmin,
}

/// What Équipe (PLAN §5.8) and the 👥 of the start screen show of the open
/// tournée. `sealed`: the screen's `switch` handles each case.
sealed class TeamState {
  const TeamState();

  /// The requests waiting for an answer: the dot on 👥.
  int get waitingRequests => 0;
}

/// No tournée is open: no 👥, nothing to show.
final class NoTeam extends TeamState {
  const NoTeam();
}

/// The tournée is being read (from the phone's copy first).
final class TeamLoading extends TeamState {
  const TeamLoading();
}

/// The tournée cannot be read: deleted, the member removed, or never read
/// on this phone while it is offline.
final class TeamUnavailable extends TeamState {
  const TeamUnavailable();
}

/// The open tournée as the member on the phone sees it.
final class TeamShown extends TeamState {
  TeamShown({
    required this.number,
    required this.centre,
    required this.campaign,
    required this.code,
    required this.qrData,
    required this.iAmAdmin,
    required this.iAmIn,
    required List<RequestRow> requests,
    required List<MemberRow> members,
  }) : requests = List.unmodifiable(requests),
       members = List.unmodifiable(members);

  /// [tournee] as [me] sees it at [now] (« il y a 2 min »): [iAmAdmin]
  /// when the phone is an admin's, [admins] the other members known to be
  /// admins.
  factory TeamShown.of(
    Tournee tournee, {
    required MemberId me,
    required DateTime now,
    required bool iAmAdmin,
    required Set<MemberId> admins,
  }) {
    return TeamShown(
      number: tournee.number.value,
      centre: tournee.centre.name,
      campaign: tournee.currentCampaign.value,
      code: tournee.joinCode.display,
      qrData: tournee.joinCode.value,
      iAmAdmin: iAmAdmin,
      iAmIn: tournee.memberOf(me) != null,
      requests: [
        for (final request in tournee.pendingMembers)
          RequestRow(
            id: request.id,
            name: request.name.text,
            asked: RecentTime.of(request.requestedAt, now: now),
          ),
      ],
      members: [
        for (final member in tournee.activeMembers)
          MemberRow(
            id: member.id,
            name: member.name.text,
            isMe: member.id == me,
            // The phone knows about itself first (`adminProvider`).
            isAdmin: member.id == me ? iAmAdmin : admins.contains(member.id),
            // An admin removes any other member, admins included; leaving
            // is « Quitter » (PLAN §5.12).
            canRemove: iAmAdmin && member.id != me,
          ),
      ],
    );
  }

  final int number;

  /// The centre de secours, as it was written.
  final String centre;

  /// The year being worked on.
  final int campaign;

  /// The join code as people read it, `K7P-2QX`.
  final String code;

  /// What the QR code holds: the code's six characters, `K7P2QX` (PLAN
  /// §5.2), which « Rejoindre » reads like a typed code.
  final String qrData;

  /// Whether the phone is an admin's (PLAN §5.12): « Nouveau code »,
  /// « Retirer » and « Supprimer la tournée » are theirs, member of the
  /// tournée or not.
  final bool iAmAdmin;

  /// Whether the member on the phone is in the team: they may « Quitter »
  /// it. Otherwise they are an admin visiting it, who « Retirer de Mes
  /// tournées » instead and is not listed in « Membres ».
  final bool iAmIn;

  /// « En attente »: the requests, oldest first. Any member or admin may
  /// answer.
  final List<RequestRow> requests;

  /// « Membres »: the accepted members, oldest first.
  final List<MemberRow> members;

  @override
  int get waitingRequests => requests.length;

  /// The first name of the member [id], pending or accepted; null for
  /// someone no longer in the team.
  String? nameOf(MemberId id) {
    for (final member in members) {
      if (member.id == id) return member.name;
    }
    for (final request in requests) {
      if (request.id == id) return request.name;
    }
    return null;
  }
}

/// A request in « En attente »: « Julie · il y a 2 min ».
final class RequestRow {
  const RequestRow({required this.id, required this.name, required this.asked});

  final MemberId id;
  final String name;

  /// When they asked to join.
  final RecentTime asked;

  @override
  bool operator ==(Object other) =>
      other is RequestRow &&
      other.id == id &&
      other.name == name &&
      other.asked == asked;

  @override
  int get hashCode => Object.hash(id, name, asked);
}

/// A member in « Membres »: « Manu (vous) · admin », « Léa [⋮] ».
final class MemberRow {
  const MemberRow({
    required this.id,
    required this.name,
    required this.isMe,
    required this.isAdmin,
    required this.canRemove,
  });

  final MemberId id;
  final String name;

  /// The member on the phone: « (vous) ».
  final bool isMe;

  /// An administrator of the app: « · admin ».
  final bool isAdmin;

  /// The member on the phone may « Retirer » this one (⋮).
  final bool canRemove;

  @override
  bool operator ==(Object other) =>
      other is MemberRow &&
      other.id == id &&
      other.name == name &&
      other.isMe == isMe &&
      other.isAdmin == isAdmin &&
      other.canRemove == canRemove;

  @override
  int get hashCode => Object.hash(id, name, isMe, isAdmin, canRemove);
}
