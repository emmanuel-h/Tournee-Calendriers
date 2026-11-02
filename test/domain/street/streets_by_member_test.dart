import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/streets_by_member.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A street of Villefranche-sur-Saône covered by [assignees].
Street _street(String id, String name, {Set<String> assignees = const {}}) =>
    valueOf(
      Street.create(
        id: StreetId(id),
        name: name,
        commune: villefranche,
        assignees: {for (final member in assignees) MemberId(member)},
      ),
    );

void main() {
  // Rue Nationale: Léa's. Rue de la Paix: nobody's. Rue Pierre Morin: Léa's
  // and Paul's. Rue Victor Hugo: Paul's.
  final nationale = _street('nationale', 'Rue Nationale', assignees: {'lea'});
  final paix = _street('paix', 'Rue de la Paix');
  final morin = _street(
    'morin',
    'Rue Pierre Morin',
    assignees: {'lea', 'paul'},
  );
  final hugo = _street('hugo', 'Rue Victor Hugo', assignees: {'paul'});
  final streets = [nationale, paix, morin, hugo];

  test('should give the names of the streets a member covers, in the order '
      'given', () {
    final byMember = StreetsByMember.of(streets);

    expect(byMember.streetsOf(lea), [
      streetName('Rue Nationale'),
      streetName('Rue Pierre Morin'),
    ]);
    expect(byMember.streetsOf(paul), [
      streetName('Rue Pierre Morin'),
      streetName('Rue Victor Hugo'),
    ]);
  });

  test('should give no street to a member who covers none', () {
    final byMember = StreetsByMember.of(streets);

    expect(byMember.streetsOf(MemberId('zoe')), isEmpty);
  });

  test('should leave out the streets in the Corbeille', () {
    final (deleted, _) = _street(
      'gare',
      'Rue de la Gare',
      assignees: {'lea'},
    ).delete(by: lea, at: twoPm);

    final byMember = StreetsByMember.of([deleted, nationale]);

    expect(byMember.streetsOf(lea), [streetName('Rue Nationale')]);
  });

  test('should give lists that cannot be modified', () {
    final byMember = StreetsByMember.of(streets);

    expect(
      () => byMember.streetsOf(lea).add(streetName('Rue Roland')),
      throwsUnsupportedError,
    );
    expect(
      () => byMember.streetsOf(MemberId('zoe')).add(streetName('Rue Roland')),
      throwsUnsupportedError,
    );
  });

  test('should give no street to anyone when there is none', () {
    expect(StreetsByMember.none.streetsOf(lea), isEmpty);
  });
}
