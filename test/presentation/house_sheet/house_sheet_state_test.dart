import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';

import '../../support/street_fixtures.dart';

void main() {
  group('LastChange.of', () {
    // Local times: the screen shows the phone's time, whatever the zone the
    // tests run in.
    final now = DateTime(2026, 10, 4, 9, 30);

    test('should be today when the change was made today', () {
      final at = DateTime(2026, 10, 4, 0, 0);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedToday(at));
    });

    test('should be earlier when the change was made the day before', () {
      final at = DateTime(2026, 10, 3, 23, 59);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedEarlier(at));
    });

    test('should be earlier when the change was made the same day of '
        'another month', () {
      final at = DateTime(2026, 9, 4, 9, 30);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedEarlier(at));
    });

    test('should be earlier when the change was made the same day of '
        'another year', () {
      final at = DateTime(2025, 10, 4, 9, 30);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedEarlier(at));
    });

    test('should give the time in the phone time zone', () {
      final change = LastChange.of(twoPm, now: twoPm);

      expect(change.at, twoPm.toLocal());
      expect(change.at.isUtc, isFalse);
    });

    test('should be equal by kind and time', () {
      final at = DateTime(2026, 10, 4, 14, 2);

      expect(ChangedToday(at), ChangedToday(DateTime(2026, 10, 4, 14, 2)));
      expect(ChangedToday(at).hashCode, ChangedToday(at).hashCode);
      expect(ChangedToday(at), isNot(ChangedEarlier(at)));
      expect(ChangedToday(at), isNot(ChangedToday(DateTime(2026, 10, 4, 14))));
      expect(ChangedEarlier(at).hashCode, ChangedEarlier(at).hashCode);
      expect(ChangedEarlier(at), isNot(ChangedToday(at)));
      expect(
        ChangedToday(at, by: const ChangedByMe()),
        isNot(ChangedToday(at)),
      );
      expect(
        ChangedEarlier(at, by: const ChangedByMember('Léa')),
        ChangedEarlier(at, by: const ChangedByMember('Léa')),
      );
      expect(ChangedToday(at).toString(), 'ChangedToday($at, null)');
      expect(ChangedEarlier(at).toString(), 'ChangedEarlier($at, null)');
    });

    test('should keep who made the change', () {
      final change = LastChange.of(
        twoPm,
        now: twoPm,
        by: const ChangedByMember('Léa'),
      );

      expect(change.by, const ChangedByMember('Léa'));
    });
  });

  group('ChangeAuthor', () {
    test('should be equal by kind and name', () {
      // Built at run time: a `const` would be built by the compiler, so
      // the constructor lines would never count as covered.
      final name = 'Léa'.trim();

      // ignore: prefer_const_constructors
      expect(ChangedByMe(), const ChangedByMe());
      // ignore: prefer_const_constructors
      expect(ChangedByMe().hashCode, const ChangedByMe().hashCode);
      expect(ChangedByMember(name), const ChangedByMember('Léa'));
      expect(
        ChangedByMember(name).hashCode,
        const ChangedByMember('Léa').hashCode,
      );
      expect(ChangedByMember(name), isNot(const ChangedByMember('Paul')));
      expect(const ChangedByMe(), isNot(ChangedByMember(name)));
    });

    test('should name itself', () {
      expect('${const ChangedByMe()}', 'ChangedByMe');
      expect('${const ChangedByMember('Léa')}', 'ChangedByMember(Léa)');
    });
  });

  group('HouseSheetState', () {
    test('should tell loading and gone apart', () {
      // Built at run time (not `const`), so coverage sees the constructors.
      // ignore: prefer_const_constructors
      final HouseSheetState loading = HouseSheetLoading();
      // ignore: prefer_const_constructors
      final HouseSheetState gone = HouseSheetGone();

      expect(loading, isNot(isA<HouseSheetGone>()));
      expect(gone, isNot(isA<HouseSheetLoading>()));
    });
  });

  group('SheetSubject', () {
    test('should tell a house, a building and a door apart', () {
      // Built at run time (not `const`), so coverage sees the constructors.
      // ignore: prefer_const_constructors
      final SheetSubject house = HouseSubject();
      // ignore: prefer_const_constructors
      final SheetSubject building = BuildingSubject();
      // ignore: prefer_const_constructors
      final SheetSubject door = DoorSubject(staircase: null);

      expect(house, isNot(isA<BuildingSubject>()));
      expect(building, isNot(isA<DoorSubject>()));
      expect(door, isNot(isA<HouseSubject>()));
    });

    test('should be the same door when the staircase is the same', () {
      expect(DoorSubject(staircase: escA), DoorSubject(staircase: escA));
      expect(
        DoorSubject(staircase: escA).hashCode,
        DoorSubject(staircase: escA).hashCode,
      );
      expect(DoorSubject(staircase: escA), isNot(DoorSubject(staircase: escB)));
      expect(
        DoorSubject(staircase: escA),
        isNot(const DoorSubject(staircase: null)),
      );
    });

    test('should name the staircase when printed', () {
      expect(
        DoorSubject(staircase: escA).toString(),
        'DoorSubject(StaircaseName(A))',
      );
    });

    HouseSheetShown withStatus(VisitStatus? status) => HouseSheetShown(
      streetName: 'Rue des Lilas',
      number: n('5'),
      status: status,
      comeBack: false,
      comeBackTime: ComeBackTime.of(null, today: day('2026-11-02')),
      lastChange: null,
    );

    test('should have no tries by default', () {
      expect(withStatus(VisitStatus.toDo).tries, 0);
    });

    for (final (status, offers) in [
      (VisitStatus.toDo, false),
      (VisitStatus.done, false),
      (VisitStatus.nobodyHome, true),
      (VisitStatus.comeBack, true),
      (null, false),
    ]) {
      test('should ${offers ? '' : 'not '}offer « Repassé, toujours '
          'personne » when the status is $status', () {
        expect(withStatus(status).offersNobodyHomeAgain, offers);
      });
    }

    test('should be about a house by default', () {
      final state = HouseSheetShown(
        streetName: 'Rue des Lilas',
        number: n('5'),
        status: VisitStatus.toDo,
        comeBack: false,
        comeBackTime: ComeBackTime.of(null, today: day('2026-11-02')),
        lastChange: null,
      );

      expect(state.subject, isA<HouseSubject>());
    });
  });
}
