import 'dart:async';

import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// An account in memory. [signedInMember] is the account kept on the phone;
/// [signInIfNeeded] gives it when there is one, otherwise [nextMember] (or
/// fails like an offline phone when it is null) once [gate] completes, so a
/// test can look at the app while the sign-in is on its way. A sign-in that
/// gives the phone its account is told on [signIns].
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

  final _signIns = StreamController<MemberId>.broadcast();

  /// Whether someone still waits for [signIns].
  bool get isWaitedFor => _signIns.hasListener;

  @override
  Stream<MemberId> get signIns => _signIns.stream;

  @override
  Future<Result<MemberId, SignInFailure>> signInIfNeeded() async {
    signInCalls++;
    await gate.future;
    final before = signedInMember;
    final member = signedInMember ??= nextMember;
    if (before == null && member != null) _signIns.add(member);
    return member == null ? const Err(SignInFailure.noNetwork) : Ok(member);
  }
}
