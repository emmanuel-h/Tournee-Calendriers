import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_state.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/results.dart';

void main() {
  SectorRow row({
    String id = 't49',
    int number = 49,
    int campaign = 2026,
    String centre = 'CS Villefranche',
    SectorRowStatus status = SectorRowStatus.open,
    int waitingRequests = 0,
    bool visited = false,
  }) => SectorRow(
    id: SectorId(id),
    number: number,
    campaign: campaign,
    centre: centre,
    status: status,
    waitingRequests: waitingRequests,
    visited: visited,
  );

  test('should compare rows field by field', () {
    expect(row(), row());
    expect(row().hashCode, row().hashCode);
    for (final other in [
      row(id: 't48'),
      row(number: 48),
      row(campaign: 2027),
      row(centre: 'CS Villefranche-sur-Saône'),
      row(status: SectorRowStatus.closed),
      row(waitingRequests: 1),
      row(visited: true),
    ]) {
      expect(row() == other, isFalse, reason: '$other');
    }
  });

  test('should compare states by their rows and open tournée', () {
    final mine = MySectors.none.remember(sector49).remember(sector12);
    final opened = valueOf(mine.open(sector49.id));

    expect(MySectorsState.of(opened), MySectorsState.of(opened));
    expect(
      MySectorsState.of(opened).hashCode,
      MySectorsState.of(opened).hashCode,
    );
    expect(MySectorsState.of(opened) == MySectorsState.of(mine), isFalse);
    expect(
      MySectorsState.of(opened) ==
          MySectorsState(
            rows: MySectorsState.of(opened).rows.reversed.toList(),
            current: sector49,
          ),
      isFalse,
    );
  });

  test('should not let the rows be changed from outside', () {
    expect(
      () => MySectorsState.of(MySectors.none).rows.add(row()),
      throwsUnsupportedError,
    );
  });

  test('should count no request waiting unless told', () {
    final mine = MySectors.none.remember(sector49).remember(sector12);

    expect(MySectorsState.of(mine).rows.map((row) => row.waitingRequests), [
      0,
      0,
    ]);
  });

  test('should show the requests waiting in each tournée', () {
    final mine = MySectors.none.remember(sector49).remember(sector12);

    final state = MySectorsState.of(mine, waiting: {sector12.id: 2});

    expect(state.rows.map((row) => row.waitingRequests), [0, 2]);
  });

  test('should mark the tournées an admin visits, open or not', () {
    final mine = valueOf(
      MySectors.none
          .remember(sector49)
          .remember(sector12Visited)
          .open(sector12Visited.id),
    );

    final rows = MySectorsState.of(mine).rows;

    expect(rows.map((row) => row.visited), [false, true]);
    expect(rows.last.status, SectorRowStatus.open);
  });

  test('should show a visited tournée not open as one to open', () {
    final mine = MySectors.none.remember(sector12Visited);

    final row = MySectorsState.of(mine).rows.single;

    expect(row.status, SectorRowStatus.closed);
    expect(row.visited, isTrue);
  });
}
