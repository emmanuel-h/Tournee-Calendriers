// The year a whole centre de secours moves from (PLAN §5.10): only when
// all its secteurs work on the same one.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/campaign_roll_over.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';

import '../../support/results.dart';

CampaignYear _year(int value) => valueOf(CampaignYear.create(value));

void main() {
  group('commonCampaignOf', () {
    test('should give the year every secteur of the centre works on', () {
      expect(
        valueOf(commonCampaignOf([_year(2026), _year(2026), _year(2026)])),
        _year(2026),
      );
    });

    test('should give the year of a centre of one secteur', () {
      expect(valueOf(commonCampaignOf([_year(2025)])), _year(2025));
    });

    test('should refuse secteurs on different years', () {
      expect(
        failureOf(commonCampaignOf([_year(2026), _year(2025)])),
        CentreRollOverRefusal.mixedYears,
      );
    });

    test('should refuse a centre without secteur', () {
      expect(
        failureOf(commonCampaignOf(const [])),
        CentreRollOverRefusal.noSector,
      );
    });
  });
}
