import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

RescueCentreKey _key(String name) => switch (RescueCentre.create(name)) {
  Ok(:final value) => value.key,
  Err(:final failure) => throw StateError('$failure'),
};

void main() {
  final villefranche = _key('CS Villefranche');
  final gleize = _key('CS Gleizé');

  group('a CS permission', () {
    final lea = AdminGrants(
      centres: {
        villefranche: {Permission.teams, Permission.streets},
        gleize: {Permission.campaign},
      },
    );

    test('should be held only in the CS it was given in', () {
      expect(lea.may(Permission.teams, villefranche), isTrue);
      expect(lea.may(Permission.streets, villefranche), isTrue);
      expect(lea.may(Permission.campaign, gleize), isTrue);
      expect(lea.may(Permission.campaign, villefranche), isFalse);
      expect(lea.may(Permission.teams, gleize), isFalse);
    });

    test('should be refused in a CS the admin holds nothing in', () {
      expect(lea.may(Permission.teams, _key('CS Anse')), isFalse);
      expect(lea.inCentre(_key('CS Anse')), isEmpty);
    });

    test('should tell the permissions held in one CS', () {
      expect(lea.inCentre(villefranche), {
        Permission.teams,
        Permission.streets,
      });
      expect(lea.inCentre(gleize), {Permission.campaign});
    });

    test('should list the CS the admin holds a permission in', () {
      expect(lea.centres, {villefranche, gleize});
      expect(lea.holdsAnyIn(villefranche), isTrue);
      expect(lea.holdsAnyIn(_key('CS Anse')), isFalse);
    });

    test('should leave out a CS given no permission', () {
      final none = AdminGrants(
        centres: {
          villefranche: {},
          gleize: {Permission.teams},
        },
      );

      expect(none.centres, {gleize});
      expect(none.holdsAnyIn(villefranche), isFalse);
    });
  });

  group('the global permissions', () {
    test('should give no permission in any CS', () {
      final superAdmin = AdminGrants(
        global: {GlobalPermission.admins, GlobalPermission.centres},
      );

      for (final permission in Permission.values) {
        expect(superAdmin.may(permission, villefranche), isFalse);
      }
      expect(superAdmin.centres, isEmpty);
    });

    test('should be held only when given', () {
      final centresOnly = AdminGrants(global: {GlobalPermission.centres});

      expect(centresOnly.holds(GlobalPermission.centres), isTrue);
      expect(centresOnly.holds(GlobalPermission.admins), isFalse);
    });
  });

  group('the role', () {
    test('should be super administrateur for the holder of « admins »', () {
      expect(
        AdminGrants(global: {GlobalPermission.admins}).role,
        AdminRole.superAdmin,
      );
      expect(
        AdminGrants(
          centres: {
            villefranche: {Permission.sectors},
          },
          global: {GlobalPermission.admins, GlobalPermission.centres},
        ).role,
        AdminRole.superAdmin,
      );
    });

    test('should be administrateur with a CS permission or « centres »', () {
      expect(
        AdminGrants(
          centres: {
            villefranche: {Permission.streets},
          },
        ).role,
        AdminRole.admin,
      );
      expect(
        AdminGrants(global: {GlobalPermission.centres}).role,
        AdminRole.admin,
      );
    });

    test('should be none without any permission', () {
      expect(AdminGrants.none.role, AdminRole.none);
      expect(AdminGrants(centres: {villefranche: {}}).role, AdminRole.none);
    });

    test('should tell whether the phone is an admin at all', () {
      expect(AdminGrants.none.isAdmin, isFalse);
      expect(AdminGrants(global: {GlobalPermission.admins}).isAdmin, isTrue);
      expect(
        AdminGrants(
          centres: {
            gleize: {Permission.teams},
          },
        ).isAdmin,
        isTrue,
      );
    });
  });

  group('creating a secteur', () {
    test('should be offered with « Secteurs » in some CS', () {
      expect(
        AdminGrants(
          centres: {
            villefranche: {Permission.teams},
            gleize: {Permission.sectors},
          },
        ).mayCreateSectors,
        isTrue,
      );
    });

    test('should be offered to the holder of « centres » (a new CS)', () {
      expect(
        AdminGrants(global: {GlobalPermission.centres}).mayCreateSectors,
        isTrue,
      );
    });

    test('should not be offered without either', () {
      expect(
        AdminGrants(
          centres: {
            villefranche: {
              Permission.campaign,
              Permission.teams,
              Permission.streets,
            },
          },
          global: {GlobalPermission.admins},
        ).mayCreateSectors,
        isFalse,
      );
      expect(AdminGrants.none.mayCreateSectors, isFalse);
    });
  });

  group('equality', () {
    AdminGrants lea() => AdminGrants(
      centres: {
        villefranche: {Permission.teams, Permission.streets},
      },
      global: {GlobalPermission.centres},
    );

    test('should be equal with the same grants, in any order', () {
      final other = AdminGrants(
        centres: {
          villefranche: {Permission.streets, Permission.teams},
        },
        global: {GlobalPermission.centres},
      );

      expect(lea(), other);
      expect(lea().hashCode, other.hashCode);
    });

    test('should differ by a CS, a permission or a global permission', () {
      expect(
        lea() ==
            AdminGrants(
              centres: {
                gleize: {Permission.teams, Permission.streets},
              },
              global: {GlobalPermission.centres},
            ),
        isFalse,
      );
      expect(
        lea() ==
            AdminGrants(
              centres: {
                villefranche: {Permission.teams},
              },
              global: {GlobalPermission.centres},
            ),
        isFalse,
      );
      expect(
        lea() ==
            AdminGrants(
              centres: {
                villefranche: {Permission.teams, Permission.streets},
              },
            ),
        isFalse,
      );
      expect(
        lea() ==
            AdminGrants(
              centres: {
                villefranche: {Permission.teams, Permission.streets},
                gleize: {Permission.teams},
              },
              global: {GlobalPermission.centres},
            ),
        isFalse,
      );
    });

    test('should differ by as many permissions, but other ones', () {
      expect(
        lea() ==
            AdminGrants(
              centres: {
                villefranche: {Permission.teams, Permission.campaign},
              },
              global: {GlobalPermission.centres},
            ),
        isFalse,
      );
      expect(
        lea() ==
            AdminGrants(
              centres: {
                villefranche: {Permission.teams, Permission.streets},
              },
              global: {GlobalPermission.admins},
            ),
        isFalse,
      );
    });

    test('should take a CS given nothing as no CS', () {
      expect(AdminGrants(centres: {villefranche: {}}), AdminGrants.none);
    });

    test('should not change when the maps given change afterwards', () {
      final permissions = {Permission.teams};
      final centres = {villefranche: permissions};
      final global = {GlobalPermission.admins};
      final grants = AdminGrants(centres: centres, global: global);

      permissions.add(Permission.sectors);
      centres[gleize] = {Permission.teams};
      global.add(GlobalPermission.centres);

      expect(grants.may(Permission.sectors, villefranche), isFalse);
      expect(grants.holdsAnyIn(gleize), isFalse);
      expect(grants.holds(GlobalPermission.centres), isFalse);
    });

    test('should name its grants when printed', () {
      expect(
        AdminGrants(
          centres: {
            villefranche: {Permission.teams},
          },
          global: {GlobalPermission.admins},
        ).toString(),
        'AdminGrants({villefranche: {teams}}, {admins})',
      );
    });
  });
}
