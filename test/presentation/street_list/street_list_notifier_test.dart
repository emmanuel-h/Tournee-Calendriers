import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_notifier.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A street of Villefranche-sur-Saône with [done] houses done out of
/// [total].
Street _street(
  String id,
  String name, {
  int done = 0,
  int total = 0,
  Commune? commune,
}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: commune ?? villefranche,
    houses: [
      for (var i = 1; i <= total; i++)
        House(
          number: n('$i'),
          status: i <= done ? VisitStatus.done : VisitStatus.toDo,
        ),
    ],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late ProviderContainer container;

  ProviderContainer containerWith(List<Street> initial) {
    streets = FakeStreetRepository(initial);
    container = ProviderContainer(
      overrides: [streetRepositoryProvider.overrideWithValue(streets)],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive for the whole test, as
    // the screen does while it shows.
    container.listen(streetListProvider, (_, _) {});
    return container;
  }

  /// Lets the repository's stream deliver its first value.
  Future<StreetListState> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(streetListProvider);
  }

  test('should be loading before the streets are read', () {
    containerWith([]);

    final state = container.read(streetListProvider);

    expect(state.loading, isTrue);
    expect(state.isEmpty, isFalse);
    expect(state.rows, isEmpty);
  });

  test('should be empty when no street was imported', () async {
    containerWith([]);

    final state = await settled();

    expect(state.loading, isFalse);
    expect(state.isEmpty, isTrue);
    expect(state.streetCount, 0);
    expect(state.communes, isEmpty);
  });

  test(
    'should give one row per street with its progress, French order',
    () async {
      containerWith([
        _street('nationale', 'Rue Nationale', done: 31, total: 40),
        _street('eglise', "Place de l'Église", done: 8, total: 8),
        _street('emile', 'Allée Émile Zola', total: 3),
      ]);

      final state = await settled();

      expect(state.loading, isFalse);
      expect(state.isEmpty, isFalse);
      expect(state.streetCount, 3);
      expect(state.communes, ['Villefranche-sur-Saône']);
      expect(state.rows, [
        StreetRow(
          id: StreetId('emile'),
          name: 'Allée Émile Zola',
          done: 0,
          total: 3,
        ),
        StreetRow(
          id: StreetId('eglise'),
          name: "Place de l'Église",
          done: 8,
          total: 8,
        ),
        StreetRow(
          id: StreetId('nationale'),
          name: 'Rue Nationale',
          done: 31,
          total: 40,
        ),
      ]);
    },
  );

  test('should follow the streets as they change', () async {
    containerWith([_street('a', 'Rue A', total: 1)]);
    await settled();

    await streets.add(_street('b', 'Rue B', done: 1, total: 2));
    final state = await settled();

    expect(state.streetCount, 2);
    expect(state.rows.last.done, 1);
  });

  test('should name each commune once, in French order', () async {
    final other = valueOf(Commune.create(inseeCode: '69265', name: 'Ébène'));
    containerWith([
      _street('a', 'Rue A'),
      _street('b', 'Rue B', commune: other),
      _street('c', 'Rue C'),
    ]);

    expect((await settled()).communes, ['Ébène', 'Villefranche-sur-Saône']);
  });

  test('should stay loading when filtered before the streets are read', () {
    containerWith([_street('nationale', 'Rue Nationale')]);

    container.read(streetListProvider.notifier).filter('nation');

    final state = container.read(streetListProvider);
    expect(state.loading, isTrue);
    expect(state.filter, 'nation');
  });

  group('filter', () {
    setUp(() {
      containerWith([
        _street('eglise', "Place de l'Église"),
        _street('nationale', 'Rue Nationale'),
      ]);
    });

    test(
      'should keep the streets whose name holds the text, any accent',
      () async {
        await settled();

        container.read(streetListProvider.notifier).filter('EGLI');
        final state = container.read(streetListProvider);

        expect(state.filter, 'EGLI');
        expect(state.rows.map((row) => row.name), ["Place de l'Église"]);
        expect(state.streetCount, 2);
        expect(state.isEmpty, isFalse);
      },
    );

    test('should keep the filter when the streets change', () async {
      await settled();
      container.read(streetListProvider.notifier).filter('nation');

      await streets.add(_street('z', 'Rue Zola'));
      final state = await settled();

      expect(state.rows.map((row) => row.name), ['Rue Nationale']);
      expect(state.streetCount, 3);
    });
  });

  group('StreetRow', () {
    StreetRow row(int done, int total) =>
        StreetRow(id: StreetId('a'), name: 'Rue A', done: done, total: total);

    test('should be complete when every house is done', () {
      expect(row(8, 8).isComplete, isTrue);
      expect(row(7, 8).isComplete, isFalse);
    });

    test('should not be complete when the street has no house', () {
      expect(row(0, 0).isComplete, isFalse);
    });

    test('should give the share of houses done', () {
      expect(row(2, 8).fraction, 0.25);
      expect(row(0, 0).fraction, 0);
    });

    test('should be equal when every field is equal', () {
      expect(row(2, 8), row(2, 8));
      expect(row(2, 8).hashCode, row(2, 8).hashCode);
      expect(row(2, 8), isNot(row(3, 8)));
      expect(row(2, 8), isNot(row(2, 9)));
      expect(
        row(2, 8),
        isNot(StreetRow(id: StreetId('b'), name: 'Rue A', done: 2, total: 8)),
      );
      expect(
        row(2, 8),
        isNot(StreetRow(id: StreetId('a'), name: 'Rue B', done: 2, total: 8)),
      );
    });
  });
}
