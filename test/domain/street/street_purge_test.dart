// The 30-day purge of the Corbeille on the Street aggregate (PLAN §5.11):
// whether a deleted street may go for good, and the numbers removed long
// enough ago to be dropped.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

/// The time the purge runs.
final _now = DateTime.utc(2026, 11, 20, 8);

DateTime _daysAgo(int days) => _now.subtract(Duration(days: days));

/// A house of the Corbeille: number [label], done, removed by Paul [days]
/// days before [_now].
RemovedHouse _removed(String label, int days) => RemovedHouse(
  house: House(
    number: n(label),
    status: VisitStatus.done,
    lastChange: leaAtTwo,
  ),
  removal: ChangeStamp(by: paul, at: _daysAgo(days)),
);

/// Rue des Lilas showing 1 and 2, with [removed] in the Corbeille and,
/// when [deletedDaysAgo] is given, itself deleted by Léa that many days
/// before [_now].
Street _street({List<RemovedHouse> removed = const [], int? deletedDaysAgo}) =>
    valueOf(
      Street.create(
        id: _lilas,
        name: 'Rue des Lilas',
        commune: villefranche,
        houses: [
          House(number: n('1')),
          House(number: n('2')),
        ],
        removedHouses: removed,
        deletion: deletedDaysAgo == null
            ? null
            : ChangeStamp(by: lea, at: _daysAgo(deletedDaysAgo)),
      ),
    );

void main() {
  group('isPastRetention of a street', () {
    test('should be false when the street is not deleted', () {
      expect(_street().isPastRetention(now: _now), isFalse);
    });

    test('should be false when the street was deleted 29 days ago', () {
      expect(_street(deletedDaysAgo: 29).isPastRetention(now: _now), isFalse);
    });

    test('should be false when the street was deleted 30 days ago', () {
      expect(_street(deletedDaysAgo: 30).isPastRetention(now: _now), isFalse);
    });

    test('should be true when the street was deleted 31 days ago', () {
      expect(_street(deletedDaysAgo: 31).isPastRetention(now: _now), isTrue);
    });
  });

  group('purgeNumbers', () {
    test('should give nothing when no number is in the Corbeille', () {
      expect(_street().purgeNumbers(now: _now), isNull);
    });

    test('should give nothing when the numbers were removed 29 and 30 days '
        'ago', () {
      final street = _street(removed: [_removed('3', 29), _removed('4', 30)]);

      expect(street.purgeNumbers(now: _now), isNull);
    });

    test('should drop the number removed 31 days ago and keep the one '
        'removed 30 days ago', () {
      final kept = _removed('4', 30);
      final old = _removed('3', 31);
      final street = _street(removed: [old, kept]);

      final (purged, change) = street.purgeNumbers(now: _now)!;

      expect(purged.removedHouses, [kept]);
      expect(purged.houses, street.houses);
      expect(purged.id, _lilas);
      expect(purged.name, streetName('Rue des Lilas'));
      expect(purged.commune, villefranche);
      expect(purged.deletion, isNull);
      expect(change, NumbersPurged(streetId: _lilas, purged: [old]));
    });

    test('should drop every number past the 30 days, in street order', () {
      final three = _removed('3', 45);
      final five = _removed('5', 31);
      final street = _street(removed: [five, three]);

      final (purged, change) = street.purgeNumbers(now: _now)!;

      expect(purged.removedHouses, isEmpty);
      expect(change.purged, [three, five]);
    });

    test('should keep the street in the Corbeille while dropping its old '
        'numbers', () {
      final street = _street(removed: [_removed('3', 31)], deletedDaysAgo: 5);

      final (purged, _) = street.purgeNumbers(now: _now)!;

      expect(purged.deletion, ChangeStamp(by: lea, at: _daysAgo(5)));
    });

    test('should free a purged number, which can be added again as a new '
        'house', () {
      final street = _street(removed: [_removed('3', 31)]);
      final (purged, _) = street.purgeNumbers(now: _now)!;

      final (added, change) = valueOf(purged.addNumbers([n('3')]));

      expect(change.added, [House(number: n('3'))]);
      expect(change.restored, isEmpty);
      expect(added.houseAt(n('3')), House(number: n('3')));
    });
  });

  group('NumbersPurged', () {
    test('should list the numbers it dropped', () {
      final change = NumbersPurged(
        streetId: _lilas,
        purged: [_removed('3', 31), _removed('5', 40)],
      );

      expect(change.numbers, [n('3'), n('5')]);
    });

    test('should be equal to another with the same street and numbers', () {
      final a = NumbersPurged(streetId: _lilas, purged: [_removed('3', 31)]);
      final b = NumbersPurged(streetId: _lilas, purged: [_removed('3', 31)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ from one of another street', () {
      final a = NumbersPurged(streetId: _lilas, purged: [_removed('3', 31)]);
      final b = NumbersPurged(
        streetId: StreetId('rue-gambetta'),
        purged: [_removed('3', 31)],
      );

      expect(a, isNot(b));
    });

    test('should differ from one with other numbers', () {
      final a = NumbersPurged(streetId: _lilas, purged: [_removed('3', 31)]);
      final b = NumbersPurged(streetId: _lilas, purged: [_removed('4', 31)]);

      expect(a, isNot(b));
    });

    test('should not let its list be modified', () {
      final change = NumbersPurged(
        streetId: _lilas,
        purged: [_removed('3', 31)],
      );

      expect(change.purged.clear, throwsUnsupportedError);
    });

    test('should name its street and numbers when printed', () {
      final change = NumbersPurged(
        streetId: _lilas,
        purged: [_removed('3', 31), _removed('5', 40)],
      );

      expect(change.toString(), 'NumbersPurged(rue-des-lilas, [3, 5])');
    });

    test('should not be undone: the houses are gone for good', () {
      final street = _street(removed: [_removed('3', 31)]);
      final (purged, change) = street.purgeNumbers(now: _now)!;

      expect(failureOf(purged.undo(change)), UndoFailure.notUndoable);
    });
  });
}
