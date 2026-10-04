// Hand-written fakes of the small application ports.
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// A clock stopped at [time]; tests move it by setting [time].
final class FakeClock implements Clock {
  FakeClock(this.time);

  DateTime time;

  @override
  DateTime now() => time;
}

/// Gives `<prefix>-1`, `<prefix>-2`… in order.
final class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator([this.prefix = 'id']);

  final String prefix;
  var _count = 0;

  @override
  String newId() => '$prefix-${++_count}';
}

/// Always the same member.
final class FakeIdentity implements IdentityProvider {
  FakeIdentity(this.currentMember);

  @override
  final MemberId currentMember;
}
