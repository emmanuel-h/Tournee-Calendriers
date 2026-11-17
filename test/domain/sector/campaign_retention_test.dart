// Which past campaigns a secteur keeps when the next one starts (PLAN
// §5.10): only the latest year that had a validated tournée.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';

import '../../support/results.dart';

CampaignYear _year(int value) => valueOf(CampaignYear.create(value));

/// A campaign of [year], with a validated tournée when [validated].
CampaignRecord _campaign(int year, {required bool validated}) =>
    CampaignRecord(year: _year(year), hasValidatedRound: validated);

void main() {
  group('yearsToDeleteAtRollOver', () {
    test('should delete nothing when the year closed is the only one and had '
        'a validated tournée', () {
      expect(
        yearsToDeleteAtRollOver([_campaign(2026, validated: true)]),
        isEmpty,
      );
    });

    test('should delete the year closed when it is the only one and had no '
        'validated tournée', () {
      expect(yearsToDeleteAtRollOver([_campaign(2026, validated: false)]), {
        _year(2026),
      });
    });

    test('should keep the year closed and delete the past one when both had '
        'a validated tournée', () {
      expect(
        yearsToDeleteAtRollOver([
          _campaign(2025, validated: true),
          _campaign(2026, validated: true),
        ]),
        {_year(2025)},
      );
    });

    test('should keep the past year and delete the year closed when only the '
        'past one had a validated tournée', () {
      expect(
        yearsToDeleteAtRollOver([
          _campaign(2025, validated: true),
          _campaign(2026, validated: false),
        ]),
        {_year(2026)},
      );
    });

    test('should keep the latest real year whatever order the years come '
        'in', () {
      expect(
        yearsToDeleteAtRollOver([
          _campaign(2026, validated: false),
          _campaign(2023, validated: true),
          _campaign(2025, validated: true),
          _campaign(2024, validated: false),
        ]),
        {_year(2023), _year(2024), _year(2026)},
      );
    });

    test('should keep the latest real year when an earlier year comes '
        'after it', () {
      expect(
        yearsToDeleteAtRollOver([
          _campaign(2025, validated: true),
          _campaign(2024, validated: true),
        ]),
        {_year(2024)},
      );
    });

    test('should delete every year when none had a validated tournée', () {
      expect(
        yearsToDeleteAtRollOver([
          _campaign(2025, validated: false),
          _campaign(2026, validated: false),
        ]),
        {_year(2025), _year(2026)},
      );
    });

    test('should delete nothing when the secteur has no campaign', () {
      expect(yearsToDeleteAtRollOver(const []), isEmpty);
    });
  });

  group('CampaignRecord', () {
    test('should be equal when the year and the tournée flag are equal', () {
      final stored = _campaign(2026, validated: true);
      final read = _campaign(2026, validated: true);

      expect(stored, read);
      expect(stored.hashCode, read.hashCode);
    });

    test('should differ when the years differ', () {
      expect(
        _campaign(2026, validated: true),
        isNot(_campaign(2025, validated: true)),
      );
    });

    test('should differ when only one had a validated tournée', () {
      expect(
        _campaign(2026, validated: true),
        isNot(_campaign(2026, validated: false)),
      );
    });

    test('should show its year and flag when printed', () {
      expect(
        _campaign(2026, validated: true).toString(),
        'CampaignRecord(2026, validated tournée: true)',
      );
    });
  });
}
