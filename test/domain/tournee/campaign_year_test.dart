import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the year when it is a campaign year', () {
      expect(valueOf(CampaignYear.create(2026)).value, 2026);
    });

    test('should accept the first year when it is 2000', () {
      expect(valueOf(CampaignYear.create(2000)).value, 2000);
    });

    test('should refuse the year when it is 1999', () {
      expect(
        failureOf(CampaignYear.create(1999)),
        CampaignYearFailure.outOfRange,
      );
    });

    test('should accept the last year when it is 2099', () {
      expect(valueOf(CampaignYear.create(2099)).value, 2099);
    });

    test('should refuse the year when it is 2100', () {
      expect(
        failureOf(CampaignYear.create(2100)),
        CampaignYearFailure.outOfRange,
      );
    });
  });

  group('parse', () {
    test('should read the year when it is typed with spaces around', () {
      expect(valueOf(CampaignYear.parse(' 2027 ')).value, 2027);
    });

    test('should read the year when it has leading zeros', () {
      expect(valueOf(CampaignYear.parse('02026')).value, 2026);
    });

    test('should refuse the text when it is not only digits', () {
      for (final typed in [
        '',
        ' ',
        '2026a',
        '+2026',
        '-2026',
        '20 26',
        '2,0',
      ]) {
        expect(
          failureOf(CampaignYear.parse(typed)),
          CampaignYearFailure.notANumber,
          reason: typed,
        );
      }
    });

    test('should refuse the year when the digits are out of range', () {
      expect(
        failureOf(CampaignYear.parse('26')),
        CampaignYearFailure.outOfRange,
      );
    });

    test('should refuse the year when the digits are too many to read', () {
      expect(
        failureOf(CampaignYear.parse('9' * 30)),
        CampaignYearFailure.outOfRange,
      );
    });
  });

  group('equality', () {
    test('should be equal when the years are equal', () {
      final typed = valueOf(CampaignYear.parse('2026'));
      final stored = valueOf(CampaignYear.create(2026));

      expect(typed, stored);
      expect(typed.hashCode, stored.hashCode);
    });

    test('should differ when the years differ', () {
      expect(
        valueOf(CampaignYear.create(2026)),
        isNot(valueOf(CampaignYear.create(2027))),
      );
    });
  });

  test('should show its year when printed', () {
    expect(valueOf(CampaignYear.create(2026)).toString(), 'CampaignYear(2026)');
  });
}
