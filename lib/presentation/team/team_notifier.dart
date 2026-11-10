import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/team.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';

/// The team of the open secteur for the whole app. Not `autoDispose`: the
/// title of Accueil shows a dot while a request waits, so the
/// team is followed as long as a secteur is open, not only while Secteur
/// is shown.
final teamProvider = NotifierProvider<TeamNotifier, TeamState>(
  TeamNotifier.new,
);

/// Shows the open tournée's team live and sends the commands of Secteur
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
  Sector? _sector;

  @override
  TeamState build() {
    _sector = null;
    // `ref.watch`: when another tournée is opened (or none), Riverpod runs
    // `build` again, which stops following the old one (`onDispose`) and
    // follows the new one.
    final sector = ref.watch(currentSectorProvider);
    if (sector == null) return const NoTeam();
    // `ref.listen`, not `ref.watch`: a change of the phone's admin status
    // redraws the team as it is, without following the tournée again.
    ref.listen(adminProvider, (_, _) => _showLast());
    final listening = ref
        .watch(observeTeamProvider)(sector.id)
        .listen(
          _show,
          // Whatever the reason, the screen can only say it cannot show
          // the team.
          onError: (Object _) => state = const TeamUnavailable(),
        );
    ref.onDispose(listening.cancel);
    return const TeamLoading();
  }

  void _show(Sector? sector) {
    _sector = sector;
    if (sector == null) {
      state = const TeamUnavailable();
      return;
    }
    _showLast();
    _askAboutAdmins(sector);
  }

  void _showLast() {
    final sector = _sector;
    if (sector == null) return;
    state = TeamShown.of(
      sector,
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

  /// Asks about each active member of [sector] not asked about yet, but
  /// the phone's own, and shows the team again with each answer.
  void _askAboutAdmins(Sector sector) {
    final me = ref.read(readCurrentMemberProvider)();
    for (final member in sector.activeMembers) {
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
      _run((sector) => ref.read(acceptMemberProvider)(sector, member));

  /// « Refuser » the request of [member].
  Future<TeamActionFailure?> refuse(MemberId member) =>
      _run((sector) => ref.read(refuseMemberProvider)(sector, member));

  /// « Retirer » [member] (admins only).
  Future<TeamActionFailure?> remove(MemberId member) =>
      _run((sector) => ref.read(removeMemberProvider)(sector, member));

  /// « Nouveau code » (admins only); needs the network.
  Future<TeamActionFailure?> regenerateCode() =>
      _run(ref.read(regenerateJoinCodeProvider).call);

  /// « + Ajouter une commune »: the tournée covers [commune] too. Works
  /// offline (sent later).
  Future<TeamActionFailure?> addCommune(CommuneOption commune) => _run(
    (sector) => ref.read(addCommuneProvider)(sector, commune.sectorCommune),
  );

  /// ✕ on the commune [code]: the tournée no longer covers it.
  Future<TeamActionFailure?> removeCommune(InseeCode code) =>
      _run((sector) => ref.read(removeCommuneProvider)(sector, code));

  /// « Quitter le secteur »: the phone forgets it, so no tournée is open
  /// any more.
  Future<TeamActionFailure?> leave() =>
      _run(ref.read(leaveSectorProvider).call);

  /// « Supprimer le secteur » (admins only); needs the network. The phone
  /// forgets it, so no tournée is open any more.
  Future<TeamActionFailure?> deleteSector() =>
      _run(ref.read(deleteSectorProvider).call);

  /// « Rejoindre » on the banner of a tournée the admin only visits (PLAN
  /// §5.12): they are in the team at once. Needs the network.
  Future<TeamActionFailure?> joinAsAdmin() =>
      _run(ref.read(joinAsAdminProvider).call);

  /// « Retirer de Mes secteurs »: the admin who only visits the open
  /// tournée forgets it on the phone, so no tournée is open any more.
  Future<void> forgetVisit() async {
    final sector = ref.read(currentSectorProvider);
    if (sector == null) return;
    await ref.read(forgetVisitedSectorProvider)(sector.id);
  }

  /// Runs [command] on the open tournée and words its failure for the
  /// screen.
  Future<TeamActionFailure?> _run(
    Future<Result<Object, TeamFailure>> Function(SectorId sector) command,
  ) async {
    final sector = ref.read(currentSectorProvider);
    if (sector == null) return TeamActionFailure.teamChanged;
    return switch (await command(sector.id)) {
      Ok() => null,
      // The admin status changed since the screen offered the command: the
      // tournée refused it as it would refuse any non-admin.
      Err(failure: TeamProblem.notAdmin) ||
      Err(
        failure: TeamCommandRefused(reason: SectorCommandFailure.notAdmin),
      ) => TeamActionFailure.notAdmin,
      Err(
        failure: TeamCommandRefused(
          reason: SectorCommandFailure.communeAlreadyIn,
        ),
      ) =>
        TeamActionFailure.communeAlreadyIn,
      Err(
        failure: TeamCommandRefused(
          reason: SectorCommandFailure.tooManyCommunes,
        ),
      ) =>
        TeamActionFailure.tooManyCommunes,
      Err(failure: TeamProblem.sectorGone || TeamCommandRefused()) =>
        TeamActionFailure.teamChanged,
      Err(failure: TeamProblem.offline) => TeamActionFailure.offline,
      Err(failure: TeamProblem.noName) => TeamActionFailure.noName,
    };
  }
}
