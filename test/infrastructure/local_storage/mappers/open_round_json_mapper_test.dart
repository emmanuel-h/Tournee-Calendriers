import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/open_round_json_mapper.dart';

import '../../../domain/round/round_fixtures.dart';

void main() {
  final round = newRound()
      .visited()
      .visited()
      .add(cash(750))
      .add(offered)
      .add(cheque(2000))
      .add(card(1000));

  final stored = {
    'version': 1,
    'round': {
      'id': 'round-1',
      'sector': 't49',
      'campaign': 2026,
      'startedAt': '2026-10-24T12:05:00.000Z',
      'housesVisited': 2,
      'donations': [
        {'method': 'cash', 'cents': 750},
        {'free': true},
        {'method': 'cheque', 'cents': 2000},
        {'method': 'card', 'cents': 1000},
      ],
    },
  };

  Map<String, Object?> storedWith(String key, Object? value) => {
    'version': 1,
    'round': {...stored['round']! as Map<String, Object?>, key: value},
  };

  test('should write the tournée on, its dons with no house nor time', () {
    expect(openRoundToJson(round), stored);
  });

  test('should write no tournée on', () {
    expect(openRoundToJson(null), {'version': 1, 'round': null});
  });

  test('should read back what it writes', () {
    expect(openRoundFromJson(stored), round);
    expect(openRoundFromJson({'version': 1, 'round': null}), isNull);
  });

  test('should read the start in UTC whatever its offset', () {
    final read = openRoundFromJson(
      storedWith('startedAt', '2026-10-24T14:05:00.000+02:00'),
    );

    expect(read!.startedAt, startedAt);
    expect(read.startedAt.isUtc, isTrue);
  });

  test('should refuse another version or another shape', () {
    expect(
      () => openRoundFromJson({...stored, 'version': 2}),
      throwsFormatException,
    );
    expect(() => openRoundFromJson({'version': 1}), throwsFormatException);
    expect(() => openRoundFromJson([stored]), throwsFormatException);
    expect(
      () => openRoundFromJson({'version': 1, 'round': 'round-1'}),
      throwsFormatException,
    );
  });

  test('should refuse a value the domain refuses', () {
    for (final (key, value) in [
      ('id', ' '),
      ('sector', ''),
      ('campaign', 1999),
      ('startedAt', 'samedi'),
      ('housesVisited', -1),
      ('housesVisited', '2'),
      ('donations', null),
    ]) {
      expect(
        () => openRoundFromJson(storedWith(key, value)),
        throwsFormatException,
        reason: '$key: $value',
      );
    }
    expect(openRoundFromJson(storedWith('housesVisited', 0))!.housesVisited, 0);
  });

  test('should refuse a don it cannot read', () {
    for (final don in [
      {'method': 'bitcoin', 'cents': 750},
      {'method': 'cash', 'cents': 0},
      {'method': 'cash', 'cents': 100001},
      {'method': 'cash'},
      {'free': false},
      'cash',
    ]) {
      expect(
        () => openRoundFromJson(storedWith('donations', [don])),
        throwsFormatException,
        reason: '$don',
      );
    }
  });
}
