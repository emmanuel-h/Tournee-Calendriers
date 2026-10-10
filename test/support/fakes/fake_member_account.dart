import 'dart:async';

import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// An account in memory. [signedInMember] is the account kept on the phone;
/// [signInIfNeeded] gives it when there is one, otherwise [nextMember] (or
/// fails like an offline phone when it is null) once [gate] completes, so a
/// test can look at the app while the sign-in is on its way.
final class FakeMemberAccount implements MemberAccount {
  FakeMemberAccount({this.signedInMember, this.nextMember});

  @override
  MemberId? signedInMember;

  /// The member the next sign-in gives; null makes it fail.
  MemberId? nextMember;

  /// Completed by the test to let [signInIfNeeded] finish; already done by
  /// default.
  Completer<void> gate = Completer<void>()..complete();

  var signInCalls = 0;

  @override
  Future<Result<MemberId, SignInFailure>> signInIfNeeded() async {
    signInCalls++;
    await gate.future;
    final member = signedInMember ??= nextMember;
    return member == null ? const Err(SignInFailure.noNetwork) : Ok(member);
  }
}
