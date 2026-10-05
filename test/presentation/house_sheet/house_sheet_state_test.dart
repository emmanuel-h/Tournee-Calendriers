import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';

import '../../support/street_fixtures.dart';

/// [count] letters `a`.
String _letters(int count) => 'a' * count;

/// A family emoji: one symbol on screen, five code points (three people
/// joined by two invisible joiners).
const _family = '👨‍👩‍👧';

void main() {
  group('TextLimit.comeBackHint', () {
    test('should allow 20 characters', () {
      expect(TextLimit.comeBackHint.max, 20);
    });

    test('should accept a hint of exactly the limit', () {
      expect(TextLimit.comeBackHint.accepts(_letters(20)), isTrue);
    });

    test('should refuse a hint one character over the limit', () {
      expect(TextLimit.comeBackHint.accepts(_letters(21)), isFalse);
    });

    test('should count code points when the text holds emoji', () {
      // 16 + 5 = 21 code points, though a person sees 17 symbols.
      final text = '${_letters(16)}$_family';

      expect(TextLimit.comeBackHint.count(text), 21);
      expect(TextLimit.comeBackHint.accepts(text), isFalse);
    });

    test('should not count the spaces around the text', () {
      final text = '  ${_letters(20)}\n ';

      expect(TextLimit.comeBackHint.count(text), 20);
      expect(TextLimit.comeBackHint.accepts(text), isTrue);
    });

    test('should agree with ComeBack.create on both sides of the limit', () {
      for (final text in [
        _letters(19),
        _letters(20),
        _letters(21),
        '${_letters(15)}$_family',
        '${_letters(16)}$_family',
      ]) {
        expect(
          TextLimit.comeBackHint.accepts(text),
          ComeBack.create(text) is Ok,
          reason: '${text.runes.length} code points',
        );
      }
    });
  });

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
      expect(ChangedToday(at).toString(), 'ChangedToday($at)');
      expect(ChangedEarlier(at).toString(), 'ChangedEarlier($at)');
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

    test('should be about a house by default', () {
      final state = HouseSheetShown(
        streetName: 'Rue des Lilas',
        number: n('5'),
        status: VisitStatus.toDo,
        comeBack: false,
        comeBackHint: '',
        lastChange: null,
      );

      expect(state.subject, isA<HouseSubject>());
    });
  });
}
