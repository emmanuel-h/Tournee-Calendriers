import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

// The administrators of the app (PLAN §5.12): whether the phone is one,
// whether a member is, every tournée of the app, and opening one of them.
// The screens show what an admin may do only once `AdminStatus` says so;
// the security rules check the same `admins/{uid}` document.

/// Whether the member on the phone is an admin, now and after each change:
/// « Créer un secteur », « Tous les secteurs », « Nouveau code »… show
/// only while it says true.
final class ObserveAdminStatus {
  const ObserveAdminStatus(this._admins);

  final AdminStatus _admins;

  Stream<bool> call() => _admins.watchIsAdmin();
}

/// Whether [MemberId] is an admin: « Léa · admin » in Équipe.
final class IsMemberAdmin {
  const IsMemberAdmin(this._admins);

  final AdminStatus _admins;

  Future<bool> call(MemberId member) => _admins.isAdmin(member);
}

/// Every tournée of the app (« Tous les secteurs »), as the admin on the
/// phone sees it: signs in first when the phone has no account yet. Needs
/// the network: fails with [DirectoryFailure.noNetwork] otherwise.
final class ListAllSectors {
  const ListAllSectors(this._directory, this._account);

  final SectorDirectory _directory;
  final MemberAccount _account;

  Future<Result<List<SectorOverview>, DirectoryFailure>> call() async {
    switch (await _account.signInIfNeeded()) {
      case Ok(value: final admin):
        return _directory.allSectors(admin);
      case Err():
        return const Err(DirectoryFailure.noNetwork);
    }
  }
}

/// Opens a tournée of « Tous les secteurs » (PLAN §5.12): kept in « Mes
/// tournées » as the admin's own when they are an active member of it,
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
