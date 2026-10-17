import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/actor.dart';

void main() {
  test('should keep who acts and whether they are an admin', () {
    final actor = Actor(member: MemberId('uid-sam'), isAdmin: true);

    expect(actor.member, MemberId('uid-sam'));
    expect(actor.isAdmin, isTrue);
  });

  test('should be equal when the member and the admin flag are', () {
    final sam = Actor(member: MemberId('uid-sam'), isAdmin: true);

    expect(sam, Actor(member: MemberId('uid-sam'), isAdmin: true));
    expect(
      sam.hashCode,
      Actor(member: MemberId('uid-sam'), isAdmin: true).hashCode,
    );
    expect(sam == Actor(member: MemberId('uid-lea'), isAdmin: true), isFalse);
    expect(sam == Actor(member: MemberId('uid-sam'), isAdmin: false), isFalse);
  });

  test('should name the member and the admin flag when printed', () {
    expect(
      Actor(member: MemberId('uid-sam'), isAdmin: true).toString(),
      'Actor(uid-sam, admin)',
    );
    expect(
      Actor(member: MemberId('uid-lea'), isAdmin: false).toString(),
      'Actor(uid-lea, member)',
    );
  });
}
