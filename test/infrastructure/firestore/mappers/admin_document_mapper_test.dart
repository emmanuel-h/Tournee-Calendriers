import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/admin_document_mapper.dart';

import '../../../support/results.dart';

void main() {
  final villefranche = valueOf(RescueCentre.create('CS Villefranche')).key;
  final gleize = valueOf(RescueCentre.create('CS Gleizé')).key;

  group('adminGrantsFrom', () {
    test('should read the CS grants and the global permissions', () {
      final grants = adminGrantsFrom({
        'name': 'Manu',
        'centres': {
          'villefranche': ['campaign', 'sectors', 'teams', 'streets'],
          'gleize': ['teams'],
        },
        'global': ['admins', 'centres'],
      });

      expect(
        grants,
        AdminGrants(
          centres: {
            villefranche: Permission.values.toSet(),
            gleize: {Permission.teams},
          },
          global: {GlobalPermission.admins, GlobalPermission.centres},
        ),
      );
    });

    test('should give nothing for no document', () {
      expect(adminGrantsFrom(null), AdminGrants.none);
    });

    test('should give nothing for a document of before PLAN §5.23, with no '
        'field', () {
      expect(adminGrantsFrom({}), AdminGrants.none);
    });

    test('should skip a permission, a global permission or a CS it does not '
        'know, keeping the others', () {
      final grants = adminGrantsFrom({
        'centres': {
          'villefranche': ['teams', 'super', 7, null],
          'Gleizé': ['teams'],
          'anse': 'teams',
        },
        'global': ['admins', 'everything', true],
      });

      expect(
        grants,
        AdminGrants(
          centres: {
            villefranche: {Permission.teams},
          },
          global: {GlobalPermission.admins},
        ),
      );
    });

    test('should give nothing for fields of another shape', () {
      expect(
        adminGrantsFrom({
          'centres': ['villefranche'],
          'global': 'admins',
        }),
        AdminGrants.none,
      );
    });
  });
}
