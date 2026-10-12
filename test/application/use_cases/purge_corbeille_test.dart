import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/purge_corbeille.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// The time the purge runs, on the fake clock.
final _now = DateTime.utc(2026, 11, 20, 8);

DateTime _daysAgo(int days) => _now.subtract(Duration(days: days));

/// Number [label], done, removed by Paul [days] days before [_now].
RemovedHouse _removed(String label, int days) => RemovedHouse(
  house: House(
    number: n(label),
    status: VisitStatus.done,
    lastChange: leaAtTwo,
  ),
  removal: ChangeStamp(by: paul, at: _daysAgo(days)),
);

/// A street [id] showing number 1, with [removed] in the Corbeille and,
/// when [deletedDaysAgo] is given, itself deleted by Léa then.
Street _street(
  String id, {
  List<RemovedHouse> removed = const [],
  int? deletedDaysAgo,
}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: 'Rue $id',
    commune: villefranche,
    houses: [House(number: n('1'))],
    removedHouses: removed,
    deletion: deletedDaysAgo == null
        ? null
        : ChangeStamp(by: lea, at: _daysAgo(deletedDaysAgo)),
  ),
);

/// Lists the streets of [inner] but has lost them all when the purge
/// reads each one: a teammate's phone purged them in the meantime.
final class _GoneMeanwhile implements StreetRepository {
  _GoneMeanwhile(this.inner);

  final FakeStreetRepository inner;

  @override
  Stream<List<Street>> watchAll() => inner.watchAll();

  @override
  Stream<List<Street>> watchDeleted() => inner.watchDeleted();

  @override
  Future<Street?> find(StreetId id) async => null;

  // Any other call is a test bug: it fails, naming the call.
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurgeCorbeille _purgeOn(FakeStreetRepository streets) =>
    PurgeCorbeille(streets, FakeClock(_now));

void main() {
  test('should remove a street deleted 31 days ago for good', () async {
    final streets = FakeStreetRepository([
      _street('Gambetta', deletedDaysAgo: 31),
    ]);

    final purged = await _purgeOn(streets)();

    expect(streets.purged, [StreetId('Gambetta')]);
    expect(await streets.find(StreetId('Gambetta')), isNull);
    expect(purged, (streets: 1, numbers: 0));
  });

  test('should keep the streets deleted 29 and 30 days ago', () async {
    final streets = FakeStreetRepository([
      _street('Gambetta', deletedDaysAgo: 29),
      _street('Lilas', deletedDaysAgo: 30),
    ]);

    final purged = await _purgeOn(streets)();

    expect(streets.purged, isEmpty);
    expect(streets.saved, isEmpty);
    expect(purged, (streets: 0, numbers: 0));
  });

  test('should drop the numbers removed 31 days ago from a street shown and '
      'keep the one removed 30 days ago', () async {
    final old = _removed('3', 31);
    final kept = _removed('4', 30);
    final lilas = _street('Lilas', removed: [old, kept]);
    final streets = FakeStreetRepository([lilas]);

    final purged = await _purgeOn(streets)();

    final (stored, change) = streets.saved.single;
    expect(stored.removedHouses, [kept]);
    expect(stored.houses, lilas.houses);
    expect(change, NumbersPurged(streetId: StreetId('Lilas'), purged: [old]));
    expect(streets.purged, isEmpty);
    expect(purged, (streets: 0, numbers: 1));
  });

  test('should drop the old numbers of a street still kept in the '
      'Corbeille', () async {
    final old = _removed('3', 40);
    final streets = FakeStreetRepository([
      _street('Gambetta', removed: [old], deletedDaysAgo: 10),
    ]);

    final purged = await _purgeOn(streets)();

    final (stored, change) = streets.saved.single;
    expect(stored.removedHouses, isEmpty);
    expect(stored.deletion, ChangeStamp(by: lea, at: _daysAgo(10)));
    expect(
      change,
      NumbersPurged(streetId: StreetId('Gambetta'), purged: [old]),
    );
    expect(purged, (streets: 0, numbers: 1));
  });

  test('should not drop the numbers of a street it removes whole', () async {
    final streets = FakeStreetRepository([
      _street('Gambetta', removed: [_removed('3', 40)], deletedDaysAgo: 31),
    ]);

    final purged = await _purgeOn(streets)();

    expect(streets.saved, isEmpty);
    expect(streets.purged, [StreetId('Gambetta')]);
    expect(purged, (streets: 1, numbers: 0));
  });

  test('should count every street and number it purged', () async {
    final streets = FakeStreetRepository([
      _street('Gambetta', deletedDaysAgo: 31),
      _street('Pasteur', deletedDaysAgo: 45),
      _street('Lilas', removed: [_removed('3', 31), _removed('5', 60)]),
      _street('Thiers', removed: [_removed('2', 35)]),
      _street('Nationale'),
    ]);

    final purged = await _purgeOn(streets)();

    expect(purged, (streets: 2, numbers: 3));
    expect(streets.purged.toSet(), {StreetId('Gambetta'), StreetId('Pasteur')});
    expect(streets.saved.map((saved) => saved.$1.id).toSet(), {
      StreetId('Lilas'),
      StreetId('Thiers'),
    });
  });

  test(
    'should purge what passed the 30 days by the time of the clock',
    () async {
      final streets = FakeStreetRepository([
        _street('Gambetta', deletedDaysAgo: 29),
      ]);
      final clock = FakeClock(_now.add(const Duration(days: 2)));

      final purged = await PurgeCorbeille(streets, clock)();

      expect(streets.purged, [StreetId('Gambetta')]);
      expect(purged, (streets: 1, numbers: 0));
    },
  );

  test('should skip a street gone by the time it is read', () async {
    final inner = FakeStreetRepository([
      _street('Gambetta', deletedDaysAgo: 31),
      _street('Lilas', removed: [_removed('3', 31)]),
    ]);

    final purged = await PurgeCorbeille(
      _GoneMeanwhile(inner),
      FakeClock(_now),
    )();

    expect(purged, (streets: 0, numbers: 0));
    expect(inner.purged, isEmpty);
    expect(inner.saved, isEmpty);
  });

  test('should fail when the streets cannot be read', () async {
    final streets = FakeStreetRepository([
      _street('Gambetta', deletedDaysAgo: 31),
    ])..watchError = StateError('no access');

    await expectLater(_purgeOn(streets)(), throwsStateError);
    expect(streets.purged, isEmpty);
  });
}
