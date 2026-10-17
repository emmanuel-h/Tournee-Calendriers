import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/results.dart';

void main() {
  TourneeRow row({
    String id = 't49',
    int number = 49,
    int campaign = 2026,
    String centre = 'CS Villefranche',
    TourneeRowStatus status = TourneeRowStatus.open,
    int waitingRequests = 0,
    bool visited = false,
  }) => TourneeRow(
    id: TourneeId(id),
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
      row(status: TourneeRowStatus.closed),
      row(waitingRequests: 1),
      row(visited: true),
    ]) {
      expect(row() == other, isFalse, reason: '$other');
    }
  });

  test('should compare states by their rows and open tournée', () {
    final mine = MyTournees.none.remember(tournee49).remember(tournee12);
    final opened = valueOf(mine.open(tournee49.id));

    expect(MyTourneesState.of(opened), MyTourneesState.of(opened));
    expect(
      MyTourneesState.of(opened).hashCode,
      MyTourneesState.of(opened).hashCode,
    );
    expect(MyTourneesState.of(opened) == MyTourneesState.of(mine), isFalse);
    expect(
      MyTourneesState.of(opened) ==
          MyTourneesState(
            rows: MyTourneesState.of(opened).rows.reversed.toList(),
            current: tournee49,
          ),
      isFalse,
    );
  });

  test('should not let the rows be changed from outside', () {
    expect(
      () => MyTourneesState.of(MyTournees.none).rows.add(row()),
      throwsUnsupportedError,
    );
  });

  test('should count no request waiting unless told', () {
    final mine = MyTournees.none.remember(tournee49).remember(tournee12);

    expect(MyTourneesState.of(mine).rows.map((row) => row.waitingRequests), [
      0,
      0,
    ]);
  });

  test('should show the requests waiting in each tournée', () {
    final mine = MyTournees.none.remember(tournee49).remember(tournee12);

    final state = MyTourneesState.of(mine, waiting: {tournee12.id: 2});

    expect(state.rows.map((row) => row.waitingRequests), [0, 2]);
  });

  test('should mark the tournées an admin visits, open or not', () {
    final mine = valueOf(
      MyTournees.none
          .remember(tournee49)
          .remember(tournee12Visited)
          .open(tournee12Visited.id),
    );

    final rows = MyTourneesState.of(mine).rows;

    expect(rows.map((row) => row.visited), [false, true]);
    expect(rows.last.status, TourneeRowStatus.open);
  });

  test('should show a visited tournée not open as one to open', () {
    final mine = MyTournees.none.remember(tournee12Visited);

    final row = MyTourneesState.of(mine).rows.single;

    expect(row.status, TourneeRowStatus.closed);
    expect(row.visited, isTrue);
  });
}
