import 'dart:async';

import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/ui/map/phone_location.dart';

/// A phone whose location service answers what the test set, and records
/// every call in [calls], in order.
final class FakePhoneLocation implements PhoneLocation {
  FakePhoneLocation({
    this.serviceEnabled = true,
    this.accessNow = LocationAccess.granted,
    this.answer = LocationAccess.granted,
    this.position,
  });

  bool serviceEnabled;

  /// What [access] returns until [requestAccess] is answered.
  LocationAccess accessNow;

  /// What the user answers to the system's dialog.
  LocationAccess answer;
  GeoPoint? position;

  /// When set, [currentPosition] waits for it instead of answering
  /// [position] at once: a GPS fix that takes a while.
  Completer<GeoPoint?>? pendingFix;

  final calls = <String>[];

  @override
  Future<bool> isServiceEnabled() async {
    calls.add('isServiceEnabled');
    return serviceEnabled;
  }

  @override
  Future<LocationAccess> access() async {
    calls.add('access');
    return accessNow;
  }

  @override
  Future<LocationAccess> requestAccess() async {
    calls.add('requestAccess');
    accessNow = answer;
    return answer;
  }

  @override
  Future<GeoPoint?> currentPosition() async {
    calls.add('currentPosition');
    return pendingFix?.future ?? position;
  }

  @override
  Future<void> openSettings() async => calls.add('openSettings');
}
