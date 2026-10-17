import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/map/phone_location.dart';

import '../../support/geo_fixtures.dart';
import 'fake_phone_location.dart';

final _townHall = at(45.98915, 4.71862);

void main() {
  group('locateMe', () {
    test(
      'should find the position without asking when already allowed',
      () async {
        final phone = FakePhoneLocation(position: _townHall);

        final outcome = await locateMe(phone);

        expect(outcome, isA<Located>());
        expect((outcome as Located).position, _townHall);
        expect(phone.calls, ['isServiceEnabled', 'access', 'currentPosition']);
      },
    );

    test('should ask, then find the position, when the user allows', () async {
      final phone = FakePhoneLocation(
        accessNow: LocationAccess.denied,
        position: _townHall,
      );

      final outcome = await locateMe(phone);

      expect((outcome as Located).position, _townHall);
      expect(phone.calls, [
        'isServiceEnabled',
        'access',
        'requestAccess',
        'currentPosition',
      ]);
    });

    test('should stop when the user refuses the dialog', () async {
      final phone = FakePhoneLocation(
        accessNow: LocationAccess.denied,
        answer: LocationAccess.denied,
        position: _townHall,
      );

      final outcome = await locateMe(phone);

      expect(outcome, isA<LocationRefused>());
      expect(phone.calls, ['isServiceEnabled', 'access', 'requestAccess']);
    });

    test('should stop when the user refuses for good in the dialog', () async {
      final phone = FakePhoneLocation(
        accessNow: LocationAccess.denied,
        answer: LocationAccess.deniedForever,
      );

      expect(await locateMe(phone), isA<LocationRefusedForever>());
    });

    test('should not ask again when the access was refused for good', () async {
      final phone = FakePhoneLocation(
        accessNow: LocationAccess.deniedForever,
        position: _townHall,
      );

      final outcome = await locateMe(phone);

      expect(outcome, isA<LocationRefusedForever>());
      expect(phone.calls, ['isServiceEnabled', 'access']);
    });

    test(
      'should stop before asking when the location service is off',
      () async {
        final phone = FakePhoneLocation(
          serviceEnabled: false,
          accessNow: LocationAccess.denied,
          position: _townHall,
        );

        final outcome = await locateMe(phone);

        expect(outcome, isA<LocationServiceOff>());
        expect(phone.calls, ['isServiceEnabled']);
      },
    );

    test('should say so when no position comes', () async {
      final phone = FakePhoneLocation();

      expect(await locateMe(phone), isA<PositionUnavailable>());
    });
  });
}
