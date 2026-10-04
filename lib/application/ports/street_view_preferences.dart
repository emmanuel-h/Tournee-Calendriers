import 'package:tournee_calendriers/domain/street/street_id.dart';

/// How the user likes each street screen shown, remembered on this phone
/// only and never shared with the team (PLAN §6.3): today, whether
/// « Masquer faits » is on for that street.
///
/// Read without waiting: the adapter loads its values before the first
/// screen (the composition root does it at start-up), so the street screen
/// opens with the right houses hidden at once, offline too.
abstract interface class StreetViewPreferences {
  /// Whether the street [id] hides its done houses; false until the user
  /// turns « Masquer faits » on for it.
  bool hidesDone(StreetId id);

  /// Remembers whether the street [id] hides its done houses. The new value
  /// is answered by [hidesDone] at once; the returned `Future` ends once it
  /// is kept on the phone.
  Future<void> setHidesDone(StreetId id, {required bool hide});
}
