// The document of an administrator (PLAN §5.23, §6.2). Pure functions,
// tested alone.
//
//   admins/{uid}   { name, addedAt, addedBy, updatedAt,
//                    centres: { villefranche: ['campaign', 'sectors',
//                                              'teams', 'streets'] },
//                    global: ['admins', 'centres'] }   ← console only
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';

/// The names a [Permission] is stored under in `centres`.
const _permissions = {
  'campaign': Permission.campaign,
  'sectors': Permission.sectors,
  'teams': Permission.teams,
  'streets': Permission.streets,
};

/// The names a [GlobalPermission] is stored under in `global`.
const _globals = {
  'admins': GlobalPermission.admins,
  'centres': GlobalPermission.centres,
};

/// What the admin document [data] grants; [AdminGrants.none] when there is
/// none (null: not an admin).
///
/// Lenient on purpose: the document is typed by hand in the console (the
/// global permissions always, the CS grants until the Administrateurs
/// screen writes them), and the security rules cannot check each value of
/// `centres` (no loops). Whatever is not a known name, a well-formed CS key
/// or a list grants nothing and is skipped, as the rules do: an unknown
/// value matches no permission there either.
AdminGrants adminGrantsFrom(Map<String, Object?>? data) {
  final centres = <RescueCentreKey, Set<Permission>>{};
  if (data?['centres'] case final Map<Object?, Object?> stored) {
    for (final MapEntry(key: name, value: permissions) in stored.entries) {
      final centre = name is String ? RescueCentreKey.fromStored(name) : null;
      if (centre == null || permissions is! List<Object?>) continue;
      centres[centre] = {
        for (final permission in permissions) ?_permissions[permission],
      };
    }
  }
  final global = <GlobalPermission>{
    if (data?['global'] case final List<Object?> stored)
      for (final permission in stored) ?_globals[permission],
  };
  return AdminGrants(centres: centres, global: global);
}
