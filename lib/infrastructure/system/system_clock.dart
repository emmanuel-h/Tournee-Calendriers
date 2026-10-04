import 'package:tournee_calendriers/application/ports/clock.dart';

/// The [Clock] of the app: the phone's time, in UTC.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
