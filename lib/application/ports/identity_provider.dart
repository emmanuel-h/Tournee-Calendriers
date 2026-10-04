import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Who is using the app on this phone: the member every change is stamped
/// with (`by` of a `ChangeStamp`).
///
/// In M1 there is no team yet: the phone makes an id once and keeps it, so
/// the user's marks stay theirs across restarts. From M2 an adapter over
/// Firebase anonymous sign-in gives the member's uid instead (PLAN §8.3);
/// the use cases do not change.
abstract interface class IdentityProvider {
  /// The member using the app. It is known before the first screen shows
  /// (the composition root loads it at start-up), so reading it needs no
  /// network and no waiting.
  MemberId get currentMember;
}
