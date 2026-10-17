import 'package:tournee_calendriers/domain/shared/geo_point.dart';

/// Whether the app may read the phone's position.
enum LocationAccess {
  /// Allowed, at least while the app is in use.
  granted,

  /// Not allowed yet: asking shows the system's dialog.
  denied,

  /// Refused for good: the system shows no dialog any more, only the
  /// phone's settings can allow it.
  deniedForever,
}

/// The phone's position, as « Me localiser » needs it (PLAN §5.3). The
/// position is only shown on the map: never stored, never sent (PLAN §8.3).
///
/// An interface so the widget tests play a phone without touching the real
/// location service; `GeolocatorPhoneLocation` is the real one.
abstract interface class PhoneLocation {
  /// Whether the phone's location service (GPS) is on.
  Future<bool> isServiceEnabled();

  /// The access the app has now, without asking anything.
  Future<LocationAccess> access();

  /// Shows the system's dialog asking for the access, and returns the
  /// answer.
  Future<LocationAccess> requestAccess();

  /// Where the phone is, or null when it cannot tell for now (no fix).
  Future<GeoPoint?> currentPosition();

  /// Opens the app's page of the phone's settings, where a refused access
  /// can be allowed.
  Future<void> openSettings();
}

/// What a tap on « Me localiser » found.
sealed class LocateOutcome {
  const LocateOutcome();
}

/// The phone is at [position].
final class Located extends LocateOutcome {
  const Located(this.position);

  final GeoPoint position;
}

/// The phone's location service is off.
final class LocationServiceOff extends LocateOutcome {
  const LocationServiceOff();
}

/// The user said no to the dialog; the next tap asks again.
final class LocationRefused extends LocateOutcome {
  const LocationRefused();
}

/// The access was refused for good: only the phone's settings can allow it.
final class LocationRefusedForever extends LocateOutcome {
  const LocationRefusedForever();
}

/// Allowed and on, but no position came (no GPS fix yet).
final class PositionUnavailable extends LocateOutcome {
  const PositionUnavailable();
}

/// Finds the phone's position for « Me localiser »: asks for the access
/// only when the app does not have it yet, so the dialog shows on the first
/// tap and never at launch (PLAN §5.3).
Future<LocateOutcome> locateMe(PhoneLocation phone) async {
  if (!await phone.isServiceEnabled()) return const LocationServiceOff();
  var access = await phone.access();
  if (access == LocationAccess.denied) access = await phone.requestAccess();
  switch (access) {
    case LocationAccess.denied:
      return const LocationRefused();
    case LocationAccess.deniedForever:
      return const LocationRefusedForever();
    case LocationAccess.granted:
      final position = await phone.currentPosition();
      return position == null ? const PositionUnavailable() : Located(position);
  }
}
