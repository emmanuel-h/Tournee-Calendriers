import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Who runs a command of a `Sector` (PLAN §5.23, §6.1): the member using
/// the phone, and the permissions they hold as an administrator.
///
/// An admin's powers are per centre de secours and per permission (an
/// `admins/{uid}` document), not per secteur: the secteur cannot tell from
/// its own members what someone may do, so the use case asks and hands
/// the answer in with the member id.
///
/// An immutable value, equal to another with the same fields.
final class Actor {
  const Actor({required this.member, this.grants = AdminGrants.none});

  /// The member acting: their uid, in the secteur or not.
  final MemberId member;

  /// What they may do as an admin; [AdminGrants.none] for a member who is
  /// no admin.
  final AdminGrants grants;

  /// Whether they hold [permission] in the CS [centre].
  bool may(Permission permission, RescueCentreKey centre) =>
      grants.may(permission, centre);

  @override
  bool operator ==(Object other) =>
      other is Actor && other.member == member && other.grants == grants;

  @override
  int get hashCode => Object.hash(member, grants);

  @override
  String toString() => 'Actor(${member.value}, $grants)';
}
