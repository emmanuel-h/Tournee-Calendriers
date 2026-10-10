import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
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
/// (PLAN §5.8). Reading works offline from the phone's copy; answering a
/// request, removing and leaving too (sent later); a new code and deleting
/// need the network.
final class TeamNotifier extends Notifier<TeamState> {
  @override
  TeamState build() {
    // `ref.watch`: when another tournée is opened (or none), Riverpod runs
    // `build` again, which stops following the old one (`onDispose`) and
    // follows the new one.
    final tournee = ref.watch(currentTourneeProvider);
    if (tournee == null) return const NoTeam();
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
    state = tournee == null
        ? const TeamUnavailable()
        : TeamShown.of(
            tournee,
            me: ref.read(readCurrentMemberProvider)(),
            // « il y a 2 min » is worked out when the team changes; the
            // clock is read here, like the house sheet's « Modifié à ».
            now: ref.read(clockProvider).now(),
          );
  }

  /// « Accepter » the request of [member]. Returns why it was not done, or
  /// null; the new team reaches [state] through the repository.
  Future<TeamActionFailure?> accept(MemberId member) =>
      _run((tournee) => ref.read(acceptMemberProvider)(tournee, member));

  /// « Refuser » the request of [member].
  Future<TeamActionFailure?> refuse(MemberId member) =>
      _run((tournee) => ref.read(refuseMemberProvider)(tournee, member));

  /// « Retirer » [member] (the creator only).
  Future<TeamActionFailure?> remove(MemberId member) =>
      _run((tournee) => ref.read(removeMemberProvider)(tournee, member));

  /// « Nouveau code » (the creator only); needs the network.
  Future<TeamActionFailure?> regenerateCode() =>
      _run(ref.read(regenerateJoinCodeProvider).call);

  /// « Quitter la tournée »: the phone forgets it, so no tournée is open
  /// any more.
  Future<TeamActionFailure?> leave() =>
      _run(ref.read(leaveTourneeProvider).call);

  /// « Supprimer la tournée » (the creator only); needs the network. The
  /// phone forgets it, so no tournée is open any more.
  Future<TeamActionFailure?> deleteTournee() =>
      _run(ref.read(deleteTourneeProvider).call);

  /// Runs [command] on the open tournée and words its failure for the
  /// screen.
  Future<TeamActionFailure?> _run(
    Future<Result<Object, TeamFailure>> Function(TourneeId tournee) command,
  ) async {
    final tournee = ref.read(currentTourneeProvider);
    if (tournee == null) return TeamActionFailure.teamChanged;
    return switch (await command(tournee.id)) {
      Ok() => null,
      Err(failure: TourneeGone() || TeamCommandRefused()) =>
        TeamActionFailure.teamChanged,
      Err(failure: TeamOffline()) => TeamActionFailure.offline,
    };
  }
}
