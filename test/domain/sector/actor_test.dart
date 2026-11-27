import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/actor.dart';
import 'package:tournee_calendriers/domain/sector/admin_grants.dart';
import 'package:tournee_calendriers/domain/sector/permission.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

import '../../support/results.dart';

void main() {
  final villefranche = valueOf(RescueCentre.create('CS Villefranche')).key;
  final gleize = valueOf(RescueCentre.create('CS Gleizé')).key;
  final teams = AdminGrants(
    centres: {
      villefranche: {Permission.teams},
    },
  );

  test('should keep who acts and what they may do', () {
    final actor = Actor(member: MemberId('uid-sam'), grants: teams);

    expect(actor.member, MemberId('uid-sam'));
    expect(actor.grants, teams);
  });

  test('should hold no permission when given none', () {
    final actor = Actor(member: MemberId('uid-lea'));

    expect(actor.grants, AdminGrants.none);
    expect(actor.may(Permission.teams, villefranche), isFalse);
  });

  test('should hold a permission only in the CS of the grant', () {
    final actor = Actor(member: MemberId('uid-sam'), grants: teams);

    expect(actor.may(Permission.teams, villefranche), isTrue);
    expect(actor.may(Permission.teams, gleize), isFalse);
    expect(actor.may(Permission.sectors, villefranche), isFalse);
  });

  test('should be equal when the member and the grants are', () {
    final sam = Actor(member: MemberId('uid-sam'), grants: teams);

    expect(sam, Actor(member: MemberId('uid-sam'), grants: teams));
    expect(
      sam.hashCode,
      Actor(member: MemberId('uid-sam'), grants: teams).hashCode,
    );
    expect(sam == Actor(member: MemberId('uid-lea'), grants: teams), isFalse);
    expect(sam == Actor(member: MemberId('uid-sam')), isFalse);
  });

  test('should name the member and the grants when printed', () {
    expect(
      Actor(member: MemberId('uid-sam'), grants: teams).toString(),
      'Actor(uid-sam, AdminGrants({villefranche: {teams}}, {}))',
    );
  });
}
