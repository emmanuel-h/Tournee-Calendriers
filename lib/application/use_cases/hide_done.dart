import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

// « Masquer faits » of the street screen (PLAN §5.6), remembered per street
// on the phone (PLAN §6.3). Two use cases, one per direction, so the screen
// reaches the preference only through use cases like everything else.

/// Whether the street screen should open with the done houses hidden.
final class ReadHideDone {
  const ReadHideDone(this._preferences);

  final StreetViewPreferences _preferences;

  /// Synchronous: the preference is on the phone and already read.
  bool call(StreetId streetId) => _preferences.hidesDone(streetId);
}

/// « Masquer faits » was toggled: remembers it for that street.
final class SaveHideDone {
  const SaveHideDone(this._preferences);

  final StreetViewPreferences _preferences;

  Future<void> call(StreetId streetId, {required bool hide}) =>
      _preferences.setHidesDone(streetId, hide: hide);
}
