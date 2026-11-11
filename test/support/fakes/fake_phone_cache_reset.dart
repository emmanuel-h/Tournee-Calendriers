import 'package:tournee_calendriers/application/ports/phone_cache_reset.dart';

/// Counts the requests to empty the phone's copy at the next start.
final class FakePhoneCacheReset implements PhoneCacheReset {
  var scheduled = 0;

  @override
  void scheduleAtNextStart() => scheduled++;
}
