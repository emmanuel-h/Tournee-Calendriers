import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

void main() {
  group('StreetNotFound', () {
    test('should equal every other street not found', () {
      expect(
        const StreetNotFound<HouseChangeFailure>(),
        const StreetNotFound<HouseChangeFailure>(),
      );
      expect(
        const StreetNotFound<HouseChangeFailure>().hashCode,
        const StreetNotFound<HouseChangeFailure>().hashCode,
      );
    });

    test('should differ from a refusal', () {
      expect(
        const StreetNotFound<HouseChangeFailure>(),
        isNot(const CommandRefused(HouseChangeFailure.unknownHouse)),
      );
    });

    test('should say so when printed', () {
      expect(
        const StreetNotFound<HouseChangeFailure>().toString(),
        'StreetNotFound',
      );
    });
  });

  group('CommandRefused', () {
    test('should carry the reason the street gave', () {
      expect(
        const CommandRefused(HouseChangeFailure.houseIsBuilding).reason,
        HouseChangeFailure.houseIsBuilding,
      );
    });

    test('should be equal when the reasons are equal', () {
      expect(
        const CommandRefused(HouseChangeFailure.unknownHouse),
        const CommandRefused(HouseChangeFailure.unknownHouse),
      );
      expect(
        const CommandRefused(HouseChangeFailure.unknownHouse).hashCode,
        const CommandRefused(HouseChangeFailure.unknownHouse).hashCode,
      );
    });

    test('should differ when the reasons differ', () {
      expect(
        const CommandRefused(HouseChangeFailure.unknownHouse),
        isNot(const CommandRefused(HouseChangeFailure.houseIsBuilding)),
      );
    });

    test('should show its reason when printed', () {
      expect(
        const CommandRefused(HouseChangeFailure.unknownHouse).toString(),
        'CommandRefused(HouseChangeFailure.unknownHouse)',
      );
    });
  });
}
