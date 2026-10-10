import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A street of Villefranche with the numbers [numbers], [removed] (by Paul
/// at [removedAt]) and, when [deletedAt] is given, deleted by Léa then.
Street street(
  String id,
  String name, {
  List<String> numbers = const [],
  Map<String, DateTime> removed = const {},
  DateTime? deletedAt,
}) {
  var street = valueOf(
    Street.create(
      id: StreetId(id),
      name: name,
      commune: villefranche,
      houses: [
        for (final label in [...numbers, ...removed.keys])
          House(number: n(label)),
      ],
    ),
  );
  for (final MapEntry(key: label, value: at) in removed.entries) {
    (street, _) = valueOf(street.removeNumber(n(label), by: paul, at: at));
  }
  if (deletedAt != null) (street, _) = street.delete(by: lea, at: deletedAt);
  return street;
}

final monday = DateTime.utc(2026, 10, 5, 12);
final tuesday = DateTime.utc(2026, 10, 6, 12);
final wednesday = DateTime.utc(2026, 10, 7, 12);

void main() {
  group('corbeilleOf', () {
    test('should list nothing when no street is deleted and no number '
        'removed', () {
      expect(
        corbeilleOf([
          street('a', 'Rue des Lilas', numbers: ['1']),
        ]),
        isEmpty,
      );
    });

    test('should list a deleted street with its shown numbers, its name and '
        'who deleted it when', () {
      final items = corbeilleOf([
        street(
          'gambetta',
          'Rue Gambetta',
          numbers: ['1', '2', '3'],
          removed: {'4': monday},
          deletedAt: tuesday,
        ),
      ]);

      expect(items, hasLength(1));
      final item = items.single as DeletedStreet;
      expect(item.streetId, StreetId('gambetta'));
      expect(item.streetName, streetName('Rue Gambetta'));
      expect(item.numberCount, 3);
      expect(item.removal, ChangeStamp(by: lea, at: tuesday));
    });

    test('should list a removed number of a street still shown, with the '
        'street and who removed it when', () {
      final items = corbeilleOf([
        street(
          'lilas',
          'Rue des Lilas',
          numbers: ['12'],
          removed: {'14ter': monday},
        ),
      ]);

      expect(items, hasLength(1));
      final item = items.single as RemovedNumber;
      expect(item.streetId, StreetId('lilas'));
      expect(item.streetName, streetName('Rue des Lilas'));
      expect(item.number, n('14ter'));
      expect(item.removal, ChangeStamp(by: paul, at: monday));
    });

    test('should leave out the removed numbers of a deleted street, which '
        'come back with it', () {
      final items = corbeilleOf([
        street(
          'gambetta',
          'Rue Gambetta',
          numbers: ['1'],
          removed: {'4': monday},
          deletedAt: tuesday,
        ),
      ]);

      expect(items.whereType<RemovedNumber>(), isEmpty);
    });

    test('should put the latest removal first', () {
      final items = corbeilleOf([
        street('a', 'Rue A', numbers: ['1'], deletedAt: monday),
        street('b', 'Rue B', removed: {'2': wednesday}, numbers: ['3']),
        street('c', 'Rue C', numbers: ['1'], deletedAt: tuesday),
      ]);

      expect(items.map((item) => item.streetId.value), ['b', 'c', 'a']);
    });

    test('should order removals made at the same time by street name, the '
        'French way, then by street id, then by number', () {
      final items = corbeilleOf([
        street('z', 'Rue Zola', numbers: ['1'], deletedAt: monday),
        street(
          'e',
          'Rue Émile',
          numbers: ['1'],
          removed: {'10': monday, '9': monday},
        ),
        street('e2', 'Rue Émile', numbers: ['1'], deletedAt: monday),
      ]);

      expect(
        items.map(
          (item) => switch (item) {
            DeletedStreet(:final streetId) => streetId.value,
            RemovedNumber(:final number) => number.label,
          },
        ),
        ['9', '10', 'e2', 'z'],
      );
    });

    test('should order two streets of the same name and time by id', () {
      final items = corbeilleOf([
        street('b', 'Rue Gambetta', numbers: ['1'], deletedAt: monday),
        street('a', 'Rue Gambetta', numbers: ['1'], deletedAt: monday),
      ]);

      expect(items.map((item) => item.streetId.value), ['a', 'b']);
    });
  });

  group('equality', () {
    final deleted = DeletedStreet(
      streetId: StreetId('g'),
      streetName: streetName('Rue Gambetta'),
      numberCount: 22,
      removal: ChangeStamp(by: paul, at: monday),
    );
    final removed = RemovedNumber(
      streetId: StreetId('l'),
      streetName: streetName('Rue des Lilas'),
      number: n('14ter'),
      removal: ChangeStamp(by: lea, at: monday),
    );

    test('should equal a deleted street with the same fields', () {
      final same = DeletedStreet(
        streetId: StreetId('g'),
        streetName: streetName('Rue Gambetta'),
        numberCount: 22,
        removal: ChangeStamp(by: paul, at: monday),
      );

      expect(same, deleted);
      expect(same.hashCode, deleted.hashCode);
      expect(deleted.toString(), 'DeletedStreet(g, 22)');
    });

    test('should differ when a field of the deleted street differs', () {
      DeletedStreet change({
        String id = 'g',
        String name = 'Rue Gambetta',
        int count = 22,
        DateTime? at,
      }) => DeletedStreet(
        streetId: StreetId(id),
        streetName: streetName(name),
        numberCount: count,
        removal: ChangeStamp(by: paul, at: at ?? monday),
      );

      expect(change(id: 'x'), isNot(deleted));
      expect(change(name: 'Rue Pasteur'), isNot(deleted));
      expect(change(count: 21), isNot(deleted));
      expect(change(at: tuesday), isNot(deleted));
    });

    test('should equal a removed number with the same fields', () {
      final same = RemovedNumber(
        streetId: StreetId('l'),
        streetName: streetName('Rue des Lilas'),
        number: n('14ter'),
        removal: ChangeStamp(by: lea, at: monday),
      );

      expect(same, removed);
      expect(same.hashCode, removed.hashCode);
      expect(removed.toString(), 'RemovedNumber(l, 14ter)');
    });

    test('should differ when a field of the removed number differs', () {
      RemovedNumber change({
        String id = 'l',
        String name = 'Rue des Lilas',
        String number = '14ter',
        DateTime? at,
      }) => RemovedNumber(
        streetId: StreetId(id),
        streetName: streetName(name),
        number: n(number),
        removal: ChangeStamp(by: lea, at: at ?? monday),
      );

      expect(change(id: 'x'), isNot(removed));
      expect(change(name: 'Rue Pasteur'), isNot(removed));
      expect(change(number: '14'), isNot(removed));
      expect(change(at: tuesday), isNot(removed));
      expect(removed, isNot(deleted));
    });
  });
}
