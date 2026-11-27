import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

// The administrators of the app (PLAN §5.12, §5.23): what the phone may
// do as one, whether a member is one, the secteurs of the admin's centres
// de secours, and opening one of them. The screens show what an admin may
// do only once `AdminStatus` says so; the security rules check the same
// `admins/{uid}` document.

/// What the member on the phone may do as an admin, now and after each
/// change: « Créer un secteur », « Tous les secteurs », « Nouveau code »…
/// show only with the permission they need.
final class ObserveAdminStatus {
  const ObserveAdminStatus(this._admins);

  final AdminStatus _admins;

  Stream<AdminGrants> call() => _admins.watchGrants();
}

/// Whether [MemberId] is an admin: « Léa · admin » in Équipe.
final class IsMemberAdmin {
  const IsMemberAdmin(this._admins);

  final AdminStatus _admins;

  Future<bool> call(MemberId member) => _admins.isAdmin(member);
}

/// The secteurs of every centre de secours the admin on the phone holds a
/// permission in (« Tous les secteurs », PLAN §5.23): signs in first when
/// the phone has no account yet. Needs the network: fails with
/// [DirectoryFailure.noNetwork] otherwise, and with
/// [DirectoryFailure.notAdmin] when the phone holds no CS (the super
/// admin's global permissions show no secteur).
final class ListAllSectors {
  const ListAllSectors(this._directory, this._account, this._admins);

  final SectorDirectory _directory;
  final MemberAccount _account;
  final AdminStatus _admins;

  Future<Result<List<SectorOverview>, DirectoryFailure>> call() async {
    switch (await _account.signInIfNeeded()) {
      case Ok(value: final admin):
        final centres = (await grantsOf(_admins)).centres;
        if (centres.isEmpty) return const Err(DirectoryFailure.notAdmin);
        return _directory.allSectors(admin, centres: centres);
      case Err():
        return const Err(DirectoryFailure.noNetwork);
    }
  }
}

/// The grants of the phone as [admins] last knew them: [AdminGrants.none]
/// until known, so an admin's command is then refused rather than sent to
/// a server that would refuse it. Grants that cannot be read count as none
/// too: the member's own commands still run, and an admin's is refused
/// with a reason the screen words, instead of an error it cannot.
Future<AdminGrants> grantsOf(AdminStatus admins) async {
  try {
    return await admins.watchGrants().first;
  } on Object {
    return AdminGrants.none;
  }
}

/// Opens a secteur of « Tous les secteurs » (PLAN §5.12): kept in « Mes
/// secteurs » as the admin's own when they are an active member of it,
/// otherwise as visited (« · administrateur »), with what the server says
/// of it now, and opened. Returns it as kept. Works with what the list
/// gave: nothing more is asked of the server.
final class OpenAsAdmin {
  const OpenAsAdmin(this._store);

  final MySectorsStore _store;

  Future<SectorSummary> call(SectorOverview sector) async {
    final summary = SectorSummary(
      id: sector.id,
      number: sector.number,
      centre: sector.centre,
      campaign: sector.campaign,
      status: sector.callerIsActive
          ? MemberStatus.active
          : MemberStatus.visiting,
    );
    // `remember` has just kept it, active or visited, so `open` always
    // succeeds: only a pending request cannot be opened.
    if (_store.mySectors.remember(summary).open(summary.id) case Ok(
      value: final opened,
    )) {
      await _store.save(opened);
    }
    return summary;
  }
}
