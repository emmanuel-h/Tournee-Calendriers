import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../support/results.dart';
import 'my_sectors_fixtures.dart';

void main() {
  /// The 49 (open), the 12 and the pending 7, in that order.
  MySectors manusPhone() => valueOf(
    MySectors.none
        .remember(sector49)
        .remember(sector12)
        .remember(sector7)
        .open(sector49.id),
  );

  group('none', () {
    test('should know no tournée and have none open', () {
      expect(MySectors.none.sectors, isEmpty);
      expect(MySectors.none.currentId, isNull);
      expect(MySectors.none.current, isNull);
    });
  });

  group('remember', () {
    test('should add a new tournée after the others, without opening it', () {
      final mine = MySectors.none.remember(sector49).remember(sector12);

      expect(mine.sectors, [sector49, sector12]);
      expect(mine.currentId, isNull);
    });

    test('should replace a known tournée in its place', () {
      final moved = summaryOf('t49', 49, campaign: campaign2027);

      final mine = manusPhone().remember(moved);

      expect(mine.sectors, [moved, sector12, sector7]);
      expect(mine.current, moved);
    });

    test('should close the open tournée when it becomes a pending request', () {
      final mine = manusPhone().remember(
        summaryOf('t49', 49, status: MemberStatus.pending),
      );

      expect(mine.currentId, isNull);
      expect(mine.sectors.first.isPending, isTrue);
    });

    test('should keep the open tournée when another one becomes pending', () {
      final mine = manusPhone().remember(
        summaryOf('t12', 12, status: MemberStatus.pending),
      );

      expect(mine.current, sector49);
    });

    test('should not let the list be changed from outside', () {
      expect(() => manusPhone().sectors.add(sector12), throwsUnsupportedError);
    });
  });

  group('open', () {
    test('should make a known active tournée the open one', () {
      final mine = valueOf(manusPhone().open(sector12.id));

      expect(mine.currentId, sector12.id);
      expect(mine.current, sector12);
      expect(mine.sectors, [sector49, sector12, sector7]);
    });

    test('should refuse a tournée the phone does not know', () {
      expect(
        failureOf(manusPhone().open(SectorId('t99'))),
        OpenSectorFailure.unknownSector,
      );
    });

    test('should open a tournée an admin visits without being in it', () {
      final mine = valueOf(
        MySectors.none.remember(sector12Visited).open(sector12Visited.id),
      );

      expect(mine.current, sector12Visited);
    });

    test('should refuse a tournée whose request is still pending', () {
      expect(
        failureOf(manusPhone().open(sector7.id)),
        OpenSectorFailure.requestPending,
      );
    });
  });

  group('forget', () {
    test('should drop a tournée and keep the open one', () {
      final mine = manusPhone().forget(sector7.id);

      expect(mine.sectors, [sector49, sector12]);
      expect(mine.current, sector49);
    });

    test('should leave no tournée open when it drops the open one', () {
      final mine = manusPhone().forget(sector49.id);

      expect(mine.sectors, [sector12, sector7]);
      expect(mine.currentId, isNull);
      expect(mine.current, isNull);
    });

    test('should change nothing when the tournée is not known', () {
      expect(manusPhone().forget(SectorId('t99')), manusPhone());
    });
  });

  group('find', () {
    test('should give the tournée of an id, or null when unknown', () {
      expect(manusPhone().find(sector12.id), sector12);
      expect(manusPhone().find(SectorId('t99')), isNull);
    });
  });

  group('equality', () {
    test('should be equal when the same tournées are in the same order and '
        'the same one is open', () {
      expect(manusPhone(), manusPhone());
      expect(manusPhone().hashCode, manusPhone().hashCode);
    });

    test('should differ when the open tournée differs', () {
      expect(manusPhone() == valueOf(manusPhone().open(sector12.id)), isFalse);
    });

    test('should differ when the tournées or their order differ', () {
      final reordered = valueOf(
        MySectors.none
            .remember(sector12)
            .remember(sector49)
            .remember(sector7)
            .open(sector49.id),
      );

      expect(manusPhone() == reordered, isFalse);
      expect(manusPhone() == manusPhone().forget(sector7.id), isFalse);
    });

    test('should name the tournées and the open one when printed', () {
      expect(manusPhone().toString(), 'MySectors(t49, t12, t7; open: t49)');
    });
  });
}
