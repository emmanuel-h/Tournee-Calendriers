import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';

void main() {
  StreetRow row({
    String id = 'lilas',
    String name = 'Rue des Lilas',
    int done = 31,
    int total = 42,
  }) => StreetRow(id: StreetId(id), name: name, done: done, total: total);

  test('should be complete when every door is visited', () {
    expect(row(done: 8, total: 8).isComplete, isTrue);
  });

  test('should not be complete when a door is still to visit', () {
    expect(row(done: 7, total: 8).isComplete, isFalse);
  });

  test('should never be complete when the street has no door', () {
    expect(row(done: 0, total: 0).isComplete, isFalse);
  });

  test('should fill the bar by the share of doors visited', () {
    expect(row(done: 3, total: 4).fraction, 0.75);
  });

  test('should leave the bar empty when the street has no door', () {
    expect(row(done: 0, total: 0).fraction, 0);
  });

  test('should equal a row of the same street, name and counts', () {
    expect(row(), row());
    expect(row().hashCode, row().hashCode);
  });

  test('should differ from a row with another field', () {
    expect(row(), isNot(row(id: 'pins')));
    expect(row(), isNot(row(name: 'Allée des Pins')));
    expect(row(), isNot(row(done: 30)));
    expect(row(), isNot(row(total: 43)));
  });

  group('unreadable (#149)', () {
    UnreadableStreetRow unreadable({
      String id = 'pasteur',
      String? name = 'Rue Pasteur',
    }) => UnreadableStreetRow(id: StreetId(id), name: name);

    test('should keep its street and name', () {
      expect(unreadable().id, StreetId('pasteur'));
      expect(unreadable().name, 'Rue Pasteur');
      expect(unreadable(name: null).name, isNull);
    });

    test('should equal a row of the same street and name', () {
      expect(unreadable(), unreadable());
      expect(unreadable().hashCode, unreadable().hashCode);
    });

    test('should differ from a row with another field', () {
      expect(unreadable(), isNot(unreadable(id: 'lilas')));
      expect(unreadable(), isNot(unreadable(name: null)));
    });

    test('should say its street and name', () {
      expect('${unreadable()}', 'UnreadableStreetRow(pasteur, Rue Pasteur)');
    });
  });
}
