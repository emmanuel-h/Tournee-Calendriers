// The houses of a new street, and the numbers added to one, are written a
// few at a time (#70): the security rules check each house a write adds,
// and can check only so many in one request.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldPath;
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_writes.dart';

import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';
import '../../local_storage/stored_street_fixtures.dart';

/// Rue de la Paix with the houses 1 to [count], each unmarked.
Street paixOf(int count) => valueOf(
  Street.create(
    id: StreetId('paix'),
    name: 'Rue de la Paix',
    commune: villefranche,
    houses: [for (var i = 1; i <= count; i++) House(number: n('$i'))],
  ),
);

FieldPath house(String label) => FieldPath(['houses', label]);

/// The entry of the house [label] of [street], as the whole document
/// holds it.
Object? entryOf(Street street, String label) =>
    (streetToDocument(street)['houses']! as Map<String, Object?>)[label];

void main() {
  test('should write as many houses per write as the security rules '
      'check', () {
    // The rules write the check out once per house (no loops): their
    // `housesPerWrite()` and its lines must say the same as the adapter.
    final rules = File('firebase/firestore.rules').readAsStringSync();
    final declared = RegExp(r'function housesPerWrite\(\) \{\s*return (\d+);')
        .firstMatch(rules)!;
    final lines = RegExp(r'isAddedHouseAt\(houses, keys, \d+\)');

    expect(int.parse(declared.group(1)!), housesPerWrite);
    expect(lines.allMatches(rules), hasLength(housesPerWrite));
  });

  group('newStreetWrites', () {
    test('should write a street without houses in its document alone', () {
      final writes = newStreetWrites(manualStreetWithout);

      expect(writes.document, streetToDocument(manualStreetWithout));
      expect(writes.updates, isEmpty);
    });

    test('should write a street of as many houses as one write holds in '
        'its document alone', () {
      final street = paixOf(housesPerWrite);

      final writes = newStreetWrites(street);

      expect(writes.document, streetToDocument(street));
      expect(writes.updates, isEmpty);
    });

    test('should write the first houses in the document and the next one '
        'in an update', () {
      final street = paixOf(housesPerWrite + 1);

      final writes = newStreetWrites(street);

      expect(writes.document['houses'], {
        for (var i = 1; i <= housesPerWrite; i++) '$i': entryOf(street, '$i'),
      });
      const last = '${housesPerWrite + 1}';
      expect(writes.updates, [
        {house(last): entryOf(street, last)},
      ]);
    });

    test('should write the next houses in order, as many per update as '
        'one write holds', () {
      final street = paixOf(2 * housesPerWrite + 1);

      final writes = newStreetWrites(street);

      expect(writes.updates, [
        {
          for (var i = housesPerWrite + 1; i <= 2 * housesPerWrite; i++)
            house('$i'): entryOf(street, '$i'),
        },
        {
          house('${2 * housesPerWrite + 1}'): entryOf(
            street,
            '${2 * housesPerWrite + 1}',
          ),
        },
      ]);
    });

    test('should keep every other field of the document as it is', () {
      final writes = newStreetWrites(richStreet);
      final whole = streetToDocument(richStreet);

      expect(
        <String, Object?>{...writes.document}..remove('houses'),
        <String, Object?>{...whole}..remove('houses'),
      );
    });

    test('should write every house once, marked or in the Corbeille, in '
        'the order of the document', () {
      final writes = newStreetWrites(richStreet);
      final whole =
          streetToDocument(richStreet)['houses']! as Map<String, Object?>;

      // Labels and entries apart: a record holding a map compares the
      // map by identity, the matcher compares maps by value.
      final labels = [
        ...(writes.document['houses']! as Map<String, Object?>).keys,
        for (final update in writes.updates)
          for (final path in update.keys) path.components.last,
      ];
      final entries = {
        ...(writes.document['houses']! as Map<String, Object?>),
        for (final update in writes.updates)
          for (final MapEntry(:key, :value) in update.entries)
            key.components.last: value,
      };

      expect(labels, whole.keys.toList());
      expect(entries, whole);
      // The number in the Corbeille comes last.
      expect(labels.last, '14ter');
    });
  });

  group('addedHouseUpdates', () {
    test('should write nothing for no house', () {
      expect(addedHouseUpdates(const {}), isEmpty);
    });

    test('should write as many houses as one write holds in one update', () {
      final entries = {
        for (var i = 1; i <= housesPerWrite; i++) '$i': {'n': i},
      };

      expect(addedHouseUpdates(entries), [
        {
          for (var i = 1; i <= housesPerWrite; i++) house('$i'): {'n': i},
        },
      ]);
    });

    test('should write one house more in an update of its own', () {
      final entries = {
        for (var i = 1; i <= housesPerWrite + 1; i++) '$i': {'n': i},
      };

      final updates = addedHouseUpdates(entries);

      expect(updates.map((update) => update.length), [housesPerWrite, 1]);
      expect(updates.last, {
        house('${housesPerWrite + 1}'): {'n': housesPerWrite + 1},
      });
    });
  });

  group('holdsHouses', () {
    test('should be false when there is no document', () {
      expect(holdsHouses(null, ['1']), isFalse);
    });

    test('should be false for a document without houses', () {
      expect(holdsHouses({'name': 'Rue de la Paix'}, ['1']), isFalse);
    });

    test('should be false when one of the houses is missing', () {
      final document = <String, Object?>{
        'houses': <String, Object?>{'1': <String, Object?>{}},
      };

      expect(holdsHouses(document, ['1', '2']), isFalse);
    });

    test('should be true when every house is there', () {
      final document = <String, Object?>{
        'houses': <String, Object?>{
          '1': <String, Object?>{},
          '2bis': <String, Object?>{},
          '3': <String, Object?>{},
        },
      };

      expect(holdsHouses(document, ['1', '2bis']), isTrue);
    });

    test('should be true for no house in an existing document', () {
      expect(holdsHouses({'houses': <String, Object?>{}}, []), isTrue);
    });
  });

  test('should read the labels an update of added houses adds', () {
    final updates = addedHouseUpdates({
      '7': <String, Object?>{},
      '7bis': <String, Object?>{},
    });

    expect(addedLabels(updates.single), ['7', '7bis']);
  });
}

/// A street typed in by hand with no number yet.
final manualStreetWithout = valueOf(
  Street.create(
    id: StreetId('manual-2'),
    name: 'Chemin des Vignes',
    commune: villefranche,
    houses: const [],
  ),
);
