import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/application/use_cases/sign_in.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

import '../../support/fakes/fake_member_account.dart';
import '../../support/results.dart';

void main() {
  final lea = MemberId('uid-lea');

  group('ReadSignedInMember', () {
    test('should be the member when the phone has an account', () {
      final account = FakeMemberAccount(signedInMember: lea);

      expect(ReadSignedInMember(account)(), lea);
    });

    test('should be null when the phone has no account yet', () {
      final account = FakeMemberAccount(nextMember: lea);

      expect(ReadSignedInMember(account)(), isNull);
      expect(account.signInCalls, 0);
    });
  });

  group('SignIn', () {
    test('should give the member once signed in', () async {
      final account = FakeMemberAccount(nextMember: lea);

      final member = valueOf(await SignIn(account)());

      expect(member, lea);
      expect(account.signInCalls, 1);
    });

    test('should fail with no network when the sign-in fails', () async {
      final account = FakeMemberAccount();

      final failure = failureOf(await SignIn(account)());

      expect(failure, SignInFailure.noNetwork);
    });
  });
}
