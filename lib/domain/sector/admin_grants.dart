import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';

/// The three roles of PLAN §5.23, as Paramètres names them under the
/// identifier of the phone (shown only to its holder).
enum AdminRole {
  /// No admin power: a member of their secteurs, nothing more.
  none,

  /// « Administrateur »: permissions in some centres de secours, or the
  /// right to create one.
  admin,

  /// « Super administrateur »: holds [GlobalPermission.admins].
  superAdmin,
}

/// What one administrator may do (PLAN §5.23): per centre de secours, some
/// of the four [Permission]s, and maybe some [GlobalPermission]s.
///
/// Read from their `admins/{uid}` document, which only the super admin
/// (the CS grants) and the Firebase console (the global ones) write. The
/// global permissions give **no** power over a secteur: the super admin's
/// own come from their CS grants, as anyone's (least privilege).
///
/// An immutable value, equal to another holding the same grants. A CS
/// given no permission is no CS at all.
final class AdminGrants {
  const AdminGrants._(this._centres, this._global);

  /// [centres]: the permissions held in each CS; [global]: those held
  /// outside any. Copied, so changing the arguments afterwards changes
  /// nothing here.
  factory AdminGrants({
    Map<RescueCentreKey, Set<Permission>> centres = const {},
    Set<GlobalPermission> global = const {},
  }) => AdminGrants._(
    Map.unmodifiable({
      for (final MapEntry(key: centre, value: permissions) in centres.entries)
        if (permissions.isNotEmpty)
          centre: Set<Permission>.unmodifiable(permissions),
    }),
    Set.unmodifiable(global),
  );

  /// No permission at all: a member who is no admin, or a phone whose
  /// grants are not known yet (nothing admin-only shows then).
  static const none = AdminGrants._({}, {});

  final Map<RescueCentreKey, Set<Permission>> _centres;
  final Set<GlobalPermission> _global;

  /// Whether [permission] is held in the CS [centre].
  bool may(Permission permission, RescueCentreKey centre) =>
      _centres[centre]?.contains(permission) ?? false;

  /// The permissions held in the CS [centre]; none when it is not one of
  /// the admin's.
  Set<Permission> inCentre(RescueCentreKey centre) =>
      _centres[centre] ?? const {};

  /// Whether some permission is held in [centre]: its secteurs show in
  /// « Tous les secteurs » and may be opened (read-only for what the
  /// permissions do not cover).
  bool holdsAnyIn(RescueCentreKey centre) => _centres.containsKey(centre);

  /// The CS the admin holds at least one permission in.
  Set<RescueCentreKey> get centres => Set.unmodifiable(_centres.keys);

  /// Whether the global [permission] is held.
  bool holds(GlobalPermission permission) => _global.contains(permission);

  /// The role Paramètres names (PLAN §5.23).
  AdminRole get role {
    if (holds(GlobalPermission.admins)) return AdminRole.superAdmin;
    return isAdmin ? AdminRole.admin : AdminRole.none;
  }

  /// Whether any permission is held, in a CS or global.
  bool get isAdmin => _centres.isNotEmpty || _global.isNotEmpty;

  /// Whether « Créer un secteur » may be offered: with « Secteurs » in
  /// some CS, or with [GlobalPermission.centres], which creates a new CS
  /// with its first secteur.
  bool get mayCreateSectors =>
      holds(GlobalPermission.centres) ||
      _centres.values.any(
        (permissions) => permissions.contains(Permission.sectors),
      );

  @override
  bool operator ==(Object other) {
    if (other is! AdminGrants ||
        other._centres.length != _centres.length ||
        other._global.length != _global.length ||
        !other._global.containsAll(_global)) {
      return false;
    }
    for (final MapEntry(key: centre, value: permissions) in _centres.entries) {
      final theirs = other._centres[centre];
      if (theirs == null ||
          theirs.length != permissions.length ||
          !theirs.containsAll(permissions)) {
        return false;
      }
    }
    return true;
  }

  // `Object.hashAllUnordered`: the same grants listed in another order
  // give the same hash, as `==` says they are equal.
  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered([
      for (final MapEntry(key: centre, value: permissions) in _centres.entries)
        Object.hash(centre, Object.hashAllUnordered(permissions)),
    ]),
    Object.hashAllUnordered(_global),
  );

  @override
  String toString() {
    final centres = [
      for (final MapEntry(key: centre, value: permissions) in _centres.entries)
        '${centre.value}: {${permissions.map((p) => p.name).join(', ')}}',
    ].join(', ');
    return 'AdminGrants({$centres}, '
        '{${_global.map((g) => g.name).join(', ')}})';
  }
}
