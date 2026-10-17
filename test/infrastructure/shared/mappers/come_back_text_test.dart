import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/infrastructure/shared/mappers/come_back_text.dart';

import '../../../support/street_fixtures.dart';

void main() {
  group('comeBackText', () {
    test('should be empty without time', () {
      expect(comeBackText(ComeBack.withoutTime), '');
    });

    test('should be the ISO day alone without hour', () {
      expect(comeBackText(comeBack('2026-10-24')), '2026-10-24');
    });

    test('should add the hour after a T, on two digits', () {
      expect(comeBackText(comeBack('2026-10-24', hour: 18)), '2026-10-24T18');
      expect(comeBackText(comeBack('2026-03-07', hour: 8)), '2026-03-07T08');
    });
  });

  group('comeBackFrom', () {
    test('should read no time from an empty text', () {
      expect(comeBackFrom(''), ComeBack.withoutTime);
    });

    test('should read a day alone', () {
      expect(comeBackFrom('2026-10-24'), comeBack('2026-10-24'));
    });

    test('should read a day and an hour', () {
      expect(comeBackFrom('2026-10-24T18'), comeBack('2026-10-24', hour: 18));
      expect(comeBackFrom('2026-03-07T08'), comeBack('2026-03-07', hour: 8));
    });

    for (final text in ['2026-10-24T08', '2026-10-24T21']) {
      test('should read the edge hour of "$text"', () {
        expect(comeBackFrom(text).hour, int.parse(text.substring(11)));
      });
    }

    for (final oldHint in ['après 19h', 'samedi', 'le soir', '19h']) {
      test(
        'should read the free hint "$oldHint" of an older app as no time',
        () {
          expect(comeBackFrom(oldHint), ComeBack.withoutTime);
        },
      );
    }

    for (final damaged in [
      '2026-02-30',
      '2026-10-24T07',
      '2026-10-24T22',
      '2026-10-24T',
      '2026-10-24T1',
      ' 2026-10-24',
      '2026-10-24 ',
      '26-10-24',
    ]) {
      test('should read "$damaged", not a time the app writes, as no time', () {
        expect(comeBackFrom(damaged), ComeBack.withoutTime);
      });
    }

    test('should read back every time it writes', () {
      for (final written in [
        ComeBack.withoutTime,
        comeBack('2026-12-31'),
        comeBack('2027-01-01', hour: 21),
      ]) {
        expect(comeBackFrom(comeBackText(written)), written);
      }
    });
  });
}
