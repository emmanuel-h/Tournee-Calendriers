import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_agenda.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';

import '../../support/street_fixtures.dart';
import 'come_back_fixtures.dart';

void main() {
  group('ComeBackAgenda.of', () {
    test('should group today and the later days in date order', () {
      final monday = entry(pinsId, '3', comeBack('2026-10-26'));
      final sunday = entry(pinsId, '5', comeBack('2026-10-25', hour: 18));
      final today = entry(lilasId, '12', comeBack('2026-10-24'));

      final agenda = ComeBackAgenda.of([
        monday,
        sunday,
        today,
      ], today: saturday);

      expect(agenda.days, [
        ComeBackDayGroup(saturday, [today]),
        ComeBackDayGroup(day('2026-10-25'), [sunday]),
        ComeBackDayGroup(day('2026-10-26'), [monday]),
      ]);
      expect(agenda.anyTime, isEmpty);
    });

    test('should put the hours first in order, then those without', () {
      final at19 = entry(nationaleId, '12', comeBack('2026-10-24', hour: 19));
      final at9 = entry(pinsId, '3', comeBack('2026-10-24', hour: 9));
      final noHour = entry(lilasId, '12', comeBack('2026-10-24'));

      final agenda = ComeBackAgenda.of([noHour, at19, at9], today: saturday);

      expect(agenda.days.single.entries, [at9, at19, noHour]);
    });

    test('should put an hour before no hour whatever the order given', () {
      final at19 = entry(nationaleId, '12', comeBack('2026-10-24', hour: 19));
      final noHour = entry(lilasId, '12', comeBack('2026-10-24'));

      for (final given in [
        [at19, noHour],
        [noHour, at19],
      ]) {
        expect(ComeBackAgenda.of(given, today: saturday).days.single.entries, [
          at19,
          noHour,
        ]);
      }
    });

    test('should order the same hour by street, then number', () {
      final lilas14 = entry(lilasId, '14', comeBack('2026-10-24', hour: 18));
      final lilas2 = entry(lilasId, '2', comeBack('2026-10-24', hour: 18));
      final pins = entry(pinsId, '30', comeBack('2026-10-24', hour: 18));

      final agenda = ComeBackAgenda.of([
        lilas14,
        pins,
        lilas2,
      ], today: saturday);

      expect(agenda.days.single.entries, [pins, lilas2, lilas14]);
    });

    test('should order those without an hour by street', () {
      final lilas = entry(lilasId, '1', comeBack('2026-10-24'));
      final pins = entry(pinsId, '1', comeBack('2026-10-24'));

      final agenda = ComeBackAgenda.of([lilas, pins], today: saturday);

      expect(agenda.days.single.entries, [pins, lilas]);
    });

    test('should put the past days and no day at any time, by address', () {
      final yesterday = entry(pasteurId, '5', comeBack('2026-10-23', hour: 18));
      final noDay = entry(pinsId, '9', ComeBack.withoutTime);
      final lastWeek = entry(lilasId, '3', comeBack('2026-10-17'));

      final agenda = ComeBackAgenda.of([
        yesterday,
        noDay,
        lastWeek,
      ], today: saturday);

      expect(agenda.days, isEmpty);
      expect(agenda.anyTime, [noDay, lastWeek, yesterday]);
    });

    test('should count every « repasser »', () {
      final agenda = ComeBackAgenda.of([
        entry(lilasId, '12', comeBack('2026-10-24')),
        entry(lilasId, '14', comeBack('2026-10-24')),
        entry(pinsId, '3', comeBack('2026-10-25')),
        entry(pinsId, '9', ComeBack.withoutTime),
      ], today: saturday);

      expect(agenda.count, 4);
    });
  });

  group('ComeBackAgenda.next', () {
    test('should be the first of the earliest day', () {
      final tomorrow = entry(pinsId, '3', comeBack('2026-10-25', hour: 8));
      final today = entry(nationaleId, '12', comeBack('2026-10-24', hour: 19));

      final agenda = ComeBackAgenda.of([
        tomorrow,
        today,
        entry(pinsId, '9', ComeBack.withoutTime),
      ], today: saturday);

      expect(agenda.next, today);
    });

    test('should be none when no « repasser » has a day from today', () {
      final agenda = ComeBackAgenda.of([
        entry(pinsId, '9', ComeBack.withoutTime),
        entry(pasteurId, '5', comeBack('2026-10-23')),
      ], today: saturday);

      expect(agenda.next, isNull);
      expect(agenda.count, 2);
    });
  });

  group('ComeBackAgenda', () {
    test('should be equal when its days and any time are equal', () {
      ComeBackAgenda of() => ComeBackAgenda.of([
        entry(lilasId, '12', comeBack('2026-10-24')),
        entry(pinsId, '9', ComeBack.withoutTime),
      ], today: saturday);

      expect(of(), of());
      expect(of().hashCode, of().hashCode);
      expect(
        of(),
        isNot(
          ComeBackAgenda.of([
            entry(lilasId, '12', comeBack('2026-10-24')),
          ], today: saturday),
        ),
      );
      expect(
        of(),
        isNot(
          ComeBackAgenda.of([
            entry(pinsId, '9', ComeBack.withoutTime),
          ], today: saturday),
        ),
      );
    });

    test('should print its days and any time', () {
      expect(
        ComeBackAgenda.of([
          entry(pinsId, '9', ComeBack.withoutTime, nobody: true),
        ], today: saturday).toString(),
        'ComeBackAgenda([], anyTime: [ComeBackEntry(ComeBackPlace(pins, 9), '
        'Allée des Pins, ComeBack(), null)])',
      );
    });
  });

  group('ComeBackDayGroup', () {
    test('should be equal when its day and entries are equal', () {
      final one = entry(lilasId, '12', comeBack('2026-10-24'));

      expect(
        ComeBackDayGroup(saturday, [one]),
        ComeBackDayGroup(saturday, [one]),
      );
      expect(
        ComeBackDayGroup(saturday, [one]).hashCode,
        ComeBackDayGroup(saturday, [one]).hashCode,
      );
      expect(
        ComeBackDayGroup(saturday, [one]),
        isNot(ComeBackDayGroup(day('2026-10-25'), [one])),
      );
      expect(
        ComeBackDayGroup(saturday, [one]),
        isNot(ComeBackDayGroup(saturday, [one, one])),
      );
    });

    test('should print its day and entries', () {
      expect(
        ComeBackDayGroup(saturday, const []).toString(),
        'ComeBackDayGroup(2026-10-24, [])',
      );
    });
  });
}
