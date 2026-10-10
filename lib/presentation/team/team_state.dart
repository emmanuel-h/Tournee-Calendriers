import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';

/// Why a command of Équipe was not done, as the screen tells it.
enum TeamActionFailure {
  /// The team changed in the meantime (a teammate answered the request
  /// first, the member was removed): the screen already shows it as it is.
  teamChanged,

  /// A new code and deleting the tournée need the network.
  offline,
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
    required this.iAmCreator,
    required List<RequestRow> requests,
    required List<MemberRow> members,
  }) : requests = List.unmodifiable(requests),
       members = List.unmodifiable(members);

  /// [tournee] as [me] sees it at [now] (« il y a 2 min »).
  factory TeamShown.of(
    Tournee tournee, {
    required MemberId me,
    required DateTime now,
  }) {
    final iAmCreator = tournee.isCreator(me);
    return TeamShown(
      number: tournee.number.value,
      centre: tournee.centre.name,
      campaign: tournee.currentCampaign.value,
      code: tournee.joinCode.display,
      qrData: tournee.joinCode.value,
      iAmCreator: iAmCreator,
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
            isCreator: tournee.isCreator(member.id),
            // The creator stays (PLAN §6.1): nobody removes them.
            canRemove: iAmCreator && !tournee.isCreator(member.id),
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

  /// Whether the member on the phone created the tournée: « Nouveau
  /// code », « Retirer » and « Supprimer la tournée » are theirs; they
  /// cannot leave.
  final bool iAmCreator;

  /// « En attente »: the requests, oldest first. Any member may answer.
  final List<RequestRow> requests;

  /// « Membres »: the accepted members, the creator first.
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

/// A member in « Membres »: « Manu (vous) · créateur », « Léa [⋮] ».
final class MemberRow {
  const MemberRow({
    required this.id,
    required this.name,
    required this.isMe,
    required this.isCreator,
    required this.canRemove,
  });

  final MemberId id;
  final String name;

  /// The member on the phone: « (vous) ».
  final bool isMe;
  final bool isCreator;

  /// The member on the phone may « Retirer » this one (⋮).
  final bool canRemove;

  @override
  bool operator ==(Object other) =>
      other is MemberRow &&
      other.id == id &&
      other.name == name &&
      other.isMe == isMe &&
      other.isCreator == isCreator &&
      other.canRemove == canRemove;

  @override
  int get hashCode => Object.hash(id, name, isMe, isCreator, canRemove);
}
