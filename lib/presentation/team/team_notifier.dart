import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';

/// The team of the open tournée for the whole app. Not `autoDispose`: the
/// start screen's 👥 shows a dot while a request waits, so the team is
/// followed as long as a tournée is open, not only while Équipe is shown.
final teamProvider = NotifierProvider<TeamNotifier, TeamState>(
  TeamNotifier.new,
);

/// Shows the open tournée's team live and sends the commands of Équipe
/// (PLAN §5.8, §5.12). Reading works offline from the phone's copy;
/// answering a request, removing and leaving too (sent later); a new code,
/// joining as an admin and deleting need the network.
///
/// It asks once about each other member whether they are an admin
/// (« · admin »), and follows whether the phone is one (`adminProvider`),
/// which gives or takes away the admin's commands at once.
final class TeamNotifier extends Notifier<TeamState> {
  /// What each member asked about turned out to be: admin or not. Kept
  /// across tournées: an admin is one everywhere.
  final _admins = <MemberId, bool>{};

  /// The tournée last read, shown again when an answer about an admin
  /// arrives or the phone's own status changes.
  Tournee? _tournee;

  @override
  TeamState build() {
    _tournee = null;
    // `ref.watch`: when another tournée is opened (or none), Riverpod runs
    // `build` again, which stops following the old one (`onDispose`) and
    // follows the new one.
    final tournee = ref.watch(currentTourneeProvider);
    if (tournee == null) return const NoTeam();
    // `ref.listen`, not `ref.watch`: a change of the phone's admin status
    // redraws the team as it is, without following the tournée again.
    ref.listen(adminProvider, (_, _) => _showLast());
    final listening = ref
        .watch(observeTeamProvider)(tournee.id)
        .listen(
          _show,
          // Whatever the reason, the screen can only say it cannot show
          // the team.
          onError: (Object _) => state = const TeamUnavailable(),
        );
    ref.onDispose(listening.cancel);
    return const TeamLoading();
  }

  void _show(Tournee? tournee) {
    _tournee = tournee;
    if (tournee == null) {
      state = const TeamUnavailable();
      return;
    }
    _showLast();
    _askAboutAdmins(tournee);
  }

  void _showLast() {
    final tournee = _tournee;
    if (tournee == null) return;
    state = TeamShown.of(
      tournee,
      me: ref.read(readCurrentMemberProvider)(),
      // « il y a 2 min » is worked out when the team changes; the clock is
      // read here, like the house sheet's « Modifié à ».
      now: ref.read(clockProvider).now(),
      iAmAdmin: ref.read(adminProvider),
      admins: {
        for (final MapEntry(key: member, value: isAdmin) in _admins.entries)
          if (isAdmin) member,
      },
    );
  }

  /// Asks about each active member of [tournee] not asked about yet, but
  /// the phone's own, and shows the team again with each answer.
  void _askAboutAdmins(Tournee tournee) {
    final me = ref.read(readCurrentMemberProvider)();
    for (final member in tournee.activeMembers) {
      if (member.id == me || _admins.containsKey(member.id)) continue;
      // Not asked twice while the answer is on its way.
      _admins[member.id] = false;
      unawaited(
        ref.read(isMemberAdminProvider)(member.id).then((isAdmin) {
          _admins[member.id] = isAdmin;
          if (ref.mounted) _showLast();
        }),
      );
    }
  }

  /// « Accepter » the request of [member]. Returns why it was not done, or
  /// null; the new team reaches [state] through the repository.
  Future<TeamActionFailure?> accept(MemberId member) =>
      _run((tournee) => ref.read(acceptMemberProvider)(tournee, member));

  /// « Refuser » the request of [member].
  Future<TeamActionFailure?> refuse(MemberId member) =>
      _run((tournee) => ref.read(refuseMemberProvider)(tournee, member));

  /// « Retirer » [member] (admins only).
  Future<TeamActionFailure?> remove(MemberId member) =>
      _run((tournee) => ref.read(removeMemberProvider)(tournee, member));

  /// « Nouveau code » (admins only); needs the network.
  Future<TeamActionFailure?> regenerateCode() =>
      _run(ref.read(regenerateJoinCodeProvider).call);

  /// « Quitter la tournée »: the phone forgets it, so no tournée is open
  /// any more.
  Future<TeamActionFailure?> leave() =>
      _run(ref.read(leaveTourneeProvider).call);

  /// « Supprimer la tournée » (admins only); needs the network. The phone
  /// forgets it, so no tournée is open any more.
  Future<TeamActionFailure?> deleteTournee() =>
      _run(ref.read(deleteTourneeProvider).call);

  /// « Rejoindre » on the banner of a tournée the admin only visits (PLAN
  /// §5.12): they are in the team at once. Needs the network.
  Future<TeamActionFailure?> joinAsAdmin() =>
      _run(ref.read(joinAsAdminProvider).call);

  /// « Retirer de Mes tournées »: the admin who only visits the open
  /// tournée forgets it on the phone, so no tournée is open any more.
  Future<void> forgetVisit() async {
    final tournee = ref.read(currentTourneeProvider);
    if (tournee == null) return;
    await ref.read(forgetVisitedTourneeProvider)(tournee.id);
  }

  /// Runs [command] on the open tournée and words its failure for the
  /// screen.
  Future<TeamActionFailure?> _run(
    Future<Result<Object, TeamFailure>> Function(TourneeId tournee) command,
  ) async {
    final tournee = ref.read(currentTourneeProvider);
    if (tournee == null) return TeamActionFailure.teamChanged;
    return switch (await command(tournee.id)) {
      Ok() => null,
      // The admin status changed since the screen offered the command: the
      // tournée refused it as it would refuse any non-admin.
      Err(failure: TeamNotAdmin()) ||
      Err(
        failure: TeamCommandRefused(reason: TourneeCommandFailure.notAdmin),
      ) => TeamActionFailure.notAdmin,
      Err(failure: TourneeGone() || TeamCommandRefused()) =>
        TeamActionFailure.teamChanged,
      Err(failure: TeamOffline()) => TeamActionFailure.offline,
      Err(failure: TeamNoName()) => TeamActionFailure.noName,
    };
  }
}
