import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';

void main() {
  test('should equal a signed-in state of the same member', () {
    final first = AccountSignedIn(MemberId('uid-lea'));
    final second = AccountSignedIn(MemberId('uid-lea'));

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.member, MemberId('uid-lea'));
  });

  test('should differ from a signed-in state of another member', () {
    expect(
      AccountSignedIn(MemberId('uid-lea')),
      isNot(AccountSignedIn(MemberId('uid-tom'))),
    );
  });

  test('should name the member when printed', () {
    expect(
      '${AccountSignedIn(MemberId('uid-lea'))}',
      'AccountSignedIn(MemberId(uid-lea))',
    );
  });
}
