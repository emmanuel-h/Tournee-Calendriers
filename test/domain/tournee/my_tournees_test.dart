import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../support/results.dart';
import 'my_tournees_fixtures.dart';

void main() {
  /// The 49 (open), the 12 and the pending 7, in that order.
  MyTournees manusPhone() => valueOf(
    MyTournees.none
        .remember(tournee49)
        .remember(tournee12)
        .remember(tournee7)
        .open(tournee49.id),
  );

  group('none', () {
    test('should know no tournée and have none open', () {
      expect(MyTournees.none.tournees, isEmpty);
      expect(MyTournees.none.currentId, isNull);
      expect(MyTournees.none.current, isNull);
    });
  });

  group('remember', () {
    test('should add a new tournée after the others, without opening it', () {
      final mine = MyTournees.none.remember(tournee49).remember(tournee12);

      expect(mine.tournees, [tournee49, tournee12]);
      expect(mine.currentId, isNull);
    });

    test('should replace a known tournée in its place', () {
      final moved = summaryOf('t49', 49, campaign: campaign2027);

      final mine = manusPhone().remember(moved);

      expect(mine.tournees, [moved, tournee12, tournee7]);
      expect(mine.current, moved);
    });

    test('should close the open tournée when it becomes a pending request', () {
      final mine = manusPhone().remember(
        summaryOf('t49', 49, status: MemberStatus.pending),
      );

      expect(mine.currentId, isNull);
      expect(mine.tournees.first.isPending, isTrue);
    });

    test('should keep the open tournée when another one becomes pending', () {
      final mine = manusPhone().remember(
        summaryOf('t12', 12, status: MemberStatus.pending),
      );

      expect(mine.current, tournee49);
    });

    test('should not let the list be changed from outside', () {
      expect(
        () => manusPhone().tournees.add(tournee12),
        throwsUnsupportedError,
      );
    });
  });

  group('open', () {
    test('should make a known active tournée the open one', () {
      final mine = valueOf(manusPhone().open(tournee12.id));

      expect(mine.currentId, tournee12.id);
      expect(mine.current, tournee12);
      expect(mine.tournees, [tournee49, tournee12, tournee7]);
    });

    test('should refuse a tournée the phone does not know', () {
      expect(
        failureOf(manusPhone().open(TourneeId('t99'))),
        OpenTourneeFailure.unknownTournee,
      );
    });

    test('should refuse a tournée whose request is still pending', () {
      expect(
        failureOf(manusPhone().open(tournee7.id)),
        OpenTourneeFailure.requestPending,
      );
    });
  });

  group('forget', () {
    test('should drop a tournée and keep the open one', () {
      final mine = manusPhone().forget(tournee7.id);

      expect(mine.tournees, [tournee49, tournee12]);
      expect(mine.current, tournee49);
    });

    test('should leave no tournée open when it drops the open one', () {
      final mine = manusPhone().forget(tournee49.id);

      expect(mine.tournees, [tournee12, tournee7]);
      expect(mine.currentId, isNull);
      expect(mine.current, isNull);
    });

    test('should change nothing when the tournée is not known', () {
      expect(manusPhone().forget(TourneeId('t99')), manusPhone());
    });
  });

  group('find', () {
    test('should give the tournée of an id, or null when unknown', () {
      expect(manusPhone().find(tournee12.id), tournee12);
      expect(manusPhone().find(TourneeId('t99')), isNull);
    });
  });

  group('equality', () {
    test('should be equal when the same tournées are in the same order and '
        'the same one is open', () {
      expect(manusPhone(), manusPhone());
      expect(manusPhone().hashCode, manusPhone().hashCode);
    });

    test('should differ when the open tournée differs', () {
      expect(manusPhone() == valueOf(manusPhone().open(tournee12.id)), isFalse);
    });

    test('should differ when the tournées or their order differ', () {
      final reordered = valueOf(
        MyTournees.none
            .remember(tournee12)
            .remember(tournee49)
            .remember(tournee7)
            .open(tournee49.id),
      );

      expect(manusPhone() == reordered, isFalse);
      expect(manusPhone() == manusPhone().forget(tournee7.id), isFalse);
    });

    test('should name the tournées and the open one when printed', () {
      expect(manusPhone().toString(), 'MyTournees(t49, t12, t7; open: t49)');
    });
  });
}
