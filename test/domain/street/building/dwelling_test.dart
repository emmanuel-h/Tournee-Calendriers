import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../../support/street_fixtures.dart';

void main() {
  group('Dwelling', () {
    test('should be to do, without come-back or change when new', () {
      final dwelling = Dwelling(label: d('51'));

      expect(dwelling.label, d('51'));
      expect(dwelling.status, VisitStatus.toDo);
      expect(dwelling.comeBack, isNull);
      expect(dwelling.lastChange, isNull);
    });

    test('should keep every field when given them', () {
      final dwelling = Dwelling(
        label: d('Gauche'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07', hour: 19),
        lastChange: leaAtTwo,
      );

      expect(dwelling.label, d('Gauche'));
      expect(dwelling.status, VisitStatus.comeBack);
      expect(dwelling.comeBack, comeBack('2026-11-07', hour: 19));
      expect(dwelling.lastChange, leaAtTwo);
    });

    test('should come back without hint when « repasser » has none', () {
      final dwelling = Dwelling(label: d('52'), status: VisitStatus.comeBack);

      expect(dwelling.comeBack, ComeBack.withoutTime);
    });

    for (final status in [
      VisitStatus.toDo,
      VisitStatus.done,
      VisitStatus.nobodyHome,
    ]) {
      test('should drop the come-back when the dwelling is $status', () {
        final dwelling = Dwelling(
          label: d('52'),
          status: status,
          comeBack: comeBack('2026-11-07'),
        );

        expect(dwelling.status, status);
        expect(dwelling.comeBack, isNull);
      });
    }

    test('should count one door with its status', () {
      final dwelling = Dwelling(
        label: d('53'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07'),
      );

      expect(dwelling.progress, Progress.of(VisitStatus.comeBack));
    });

    group('equality', () {
      Dwelling full() => Dwelling(
        label: d('51'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07', hour: 19),
        lastChange: leaAtTwo,
      );

      test('should be equal when every field is equal', () {
        expect(full(), full());
        expect(full().hashCode, full().hashCode);
      });

      final others = <String, Dwelling>{
        'label': Dwelling(
          label: d('52'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('2026-11-07', hour: 19),
          lastChange: leaAtTwo,
        ),
        'status': Dwelling(
          label: d('51'),
          status: VisitStatus.nobodyHome,
          lastChange: leaAtTwo,
        ),
        'come-back': Dwelling(
          label: d('51'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('2026-11-07', hour: 20),
          lastChange: leaAtTwo,
        ),
        'last change': Dwelling(
          label: d('51'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('2026-11-07', hour: 19),
          lastChange: paulAtThree,
        ),
        'tries': Dwelling(
          label: d('51'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('2026-11-07', hour: 19),
          lastChange: leaAtTwo,
          tries: tries(2),
        ),
      };
      others.forEach((field, other) {
        test('should differ when the ${field}s differ', () {
          expect(full(), isNot(other));
        });
      });
    });

    group('tries', () {
      test('should have none when new', () {
        expect(Dwelling(label: d('51')).tries, NobodyHomeTries.none);
      });

      test('should keep its tries when nobody is home', () {
        final dwelling = Dwelling(
          label: d('51'),
          status: VisitStatus.nobodyHome,
          tries: tries(3),
        );

        expect(dwelling.tries, tries(3));
      });

      test('should count one try when nobody is home without any given', () {
        final dwelling = Dwelling(
          label: d('51'),
          status: VisitStatus.nobodyHome,
        );

        expect(dwelling.tries, tries(1));
      });

      test('should drop its tries when to do', () {
        final dwelling = Dwelling(label: d('51'), tries: tries(3));

        expect(dwelling.tries, NobodyHomeTries.none);
      });

      test('should keep its tries when restamped', () {
        final dwelling = Dwelling(
          label: d('51'),
          status: VisitStatus.done,
          tries: tries(2),
          lastChange: leaAtTwo,
        );

        expect(dwelling.restampedBy(paul).tries, tries(2));
      });
    });

    test('should show its tries after its fields when it has some', () {
      final dwelling = Dwelling(
        label: d('51'),
        status: VisitStatus.done,
        tries: tries(2),
      );

      expect(
        dwelling.toString(),
        'Dwelling(51, VisitStatus.done, null, null, ×2)',
      );
    });

    test('should show its fields when printed', () {
      final dwelling = Dwelling(
        label: d('51'),
        status: VisitStatus.done,
        lastChange: leaAtTwo,
      );

      expect(
        dwelling.toString(),
        'Dwelling(51, VisitStatus.done, null, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('DwellingKey', () {
    test('should name the staircase, the floor and the label', () {
      final key = DwellingKey(escA, 5, d('51'));

      expect(key.staircase, escA);
      expect(key.level, 5);
      expect(key.label, d('51'));
    });

    final ids = <String, (DwellingKey, String)>{
      'a numbered door': (DwellingKey(escA, 5, d('51')), 'A5-51'),
      'a door of the RdC': (DwellingKey(escA, 0, d('Gauche')), 'A0-Gauche'),
      'a door of a two-digit floor': (DwellingKey(escB, 12, d('3')), 'B12-3'),
      'a door when floors are unknown': (
        DwellingKey(escB, null, d('Gauche')),
        'B-Gauche',
      ),
      'a label holding a dash': (DwellingKey(escA, 1, d('1-2')), 'A1-1-2'),
    };
    ids.forEach((what, given) {
      test('should give ${given.$2} as the id of $what', () {
        expect(given.$1.id, given.$2);
      });
    });

    test(
      'should give different ids to floor 1 door 11 and floor 11 door 1',
      () {
        expect(
          DwellingKey(escA, 1, d('11')).id,
          isNot(DwellingKey(escA, 11, d('1')).id),
        );
      },
    );

    test('should be equal when staircase, floor and label are equal', () {
      expect(DwellingKey(escA, 5, d('51')), DwellingKey(escA, 5, d('51')));
      expect(
        DwellingKey(escA, 5, d('51')).hashCode,
        DwellingKey(escA, 5, d('51')).hashCode,
      );
    });

    test('should differ when the staircases differ', () {
      expect(
        DwellingKey(escA, 5, d('51')),
        isNot(DwellingKey(escB, 5, d('51'))),
      );
    });

    test('should differ when the floors differ', () {
      expect(
        DwellingKey(escA, 1, d('Gauche')),
        isNot(DwellingKey(escA, 2, d('Gauche'))),
      );
      expect(
        DwellingKey(escA, 0, d('Gauche')),
        isNot(DwellingKey(escA, null, d('Gauche'))),
      );
    });

    test('should differ when the labels differ', () {
      expect(
        DwellingKey(escA, 5, d('51')),
        isNot(DwellingKey(escA, 5, d('52'))),
      );
    });

    test('should show its id when printed', () {
      expect(DwellingKey(escB, 2, d('1')).toString(), 'DwellingKey(B2-1)');
    });
  });
}
