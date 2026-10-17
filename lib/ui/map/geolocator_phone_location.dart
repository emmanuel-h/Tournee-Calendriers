import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/ui/map/phone_location.dart';

/// [PhoneLocation] on the phone's location service, through `geolocator`.
/// Platform glue, covered by the device checklist (PLAN §11).
final class GeolocatorPhoneLocation implements PhoneLocation {
  const GeolocatorPhoneLocation();

  /// How long to wait for a fresh fix before falling back on the last one
  /// the phone knows: under a roof or between tall buildings, a fix may
  /// take a while.
  static const _fixTimeLimit = Duration(seconds: 10);

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> access() async =>
      _accessOf(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestAccess() async =>
      _accessOf(await Geolocator.requestPermission());

  @override
  Future<GeoPoint?> currentPosition() async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: _fixTimeLimit),
      );
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();
    } on LocationServiceDisabledException {
      return null;
    }
    if (position == null) return null;
    return switch (GeoPoint.create(
      latitude: position.latitude,
      longitude: position.longitude,
    )) {
      Ok(:final value) => value,
      Err() => null,
    };
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();

  static LocationAccess _accessOf(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.whileInUse ||
        LocationPermission.always => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        // `unableToDetermine` only happens in some web browsers.
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationAccess.denied,
      };
}
