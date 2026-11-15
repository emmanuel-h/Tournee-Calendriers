import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/open_round_json_mapper.dart';

import '../../../domain/round/round_fixtures.dart';
import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';

void main() {
  final round = newRound()
      .visited()
      .visited()
      .add(cash(750))
      .add(offered)
      .add(cheque(2000))
      .add(card(1000));

  final storedRound = {
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
  };

  /// Friday's tournée of the 12 in 2027, refused by the server.
  final refused = UnsentRound(
    sector: SectorId('t12'),
    campaign: valueOf(CampaignYear.create(2027)),
    summary: RoundSummary(
      id: RoundId('round-0'),
      startedAt: DateTime.utc(2026, 10, 23, 15),
      endedAt: DateTime.utc(2026, 10, 23, 17, 30),
      housesVisited: 8,
      totals: DonationTotals(
        cash: MethodTotal(count: 3, cents: 4000),
        cheque: MethodTotal(count: 1, cents: 1500),
        card: MethodTotal(count: 2, cents: 2500),
        free: 1,
      ),
    ),
    state: UnsentState.refused,
  );

  final storedRefused = {
    'sector': 't12',
    'campaign': 2027,
    'refused': true,
    'summary': {
      'id': 'round-0',
      'startedAt': '2026-10-23T15:00:00.000Z',
      'endedAt': '2026-10-23T17:30:00.000Z',
      'housesVisited': 8,
      'free': 1,
      'cash': {'count': 3, 'cents': 4000},
      'cheque': {'count': 1, 'cents': 1500},
      'card': {'count': 2, 'cents': 2500},
    },
  };

  final waiting = refused.retried();
  final storedWaiting = {...storedRefused, 'refused': false};

  final stored = {
    'version': 2,
    'round': storedRound,
    'unsent': [storedRefused, storedWaiting],
  };

  Map<String, Object?> storedWith(String key, Object? value) => {
    'version': 2,
    'round': {...storedRound, key: value},
    'unsent': const <Object?>[],
  };

  Map<String, Object?> unsentWith(Map<String, Object?> entry) => {
    'version': 2,
    'round': null,
    'unsent': [entry],
  };

  Map<String, Object?> summaryWith(String key, Object? value) => unsentWith({
    ...storedRefused,
    'summary': {
      ...storedRefused['summary']! as Map<String, Object?>,
      key: value,
    },
  });

  test('should write the tournée on, its dons with no house nor time, and '
      'the tournées not yet sent', () {
    expect(roundsToJson((open: round, unsent: [refused, waiting])), stored);
  });

  test('should write no tournée on and none waiting', () {
    expect(roundsToJson((open: null, unsent: const [])), {
      'version': 2,
      'round': null,
      'unsent': <Object?>[],
    });
  });

  test('should read back what it writes', () {
    final rounds = roundsFromJson(stored);
    final none = roundsFromJson({
      'version': 2,
      'round': null,
      'unsent': <Object?>[],
    });

    expect(rounds.open, round);
    expect(rounds.unsent, [refused, waiting]);
    expect(none.open, isNull);
    expect(none.unsent, isEmpty);
  });

  test('should read a file of version 1 as none waiting', () {
    final on = roundsFromJson({'version': 1, 'round': storedRound});
    final off = roundsFromJson({'version': 1, 'round': null});

    expect(on.open, round);
    expect(on.unsent, isEmpty);
    expect(off.open, isNull);
    expect(off.unsent, isEmpty);
  });

  test('should read the times in UTC whatever their offset', () {
    final read = roundsFromJson(
      storedWith('startedAt', '2026-10-24T14:05:00.000+02:00'),
    );
    final summary = roundsFromJson(
      summaryWith('endedAt', '2026-10-23T19:30:00.000+02:00'),
    ).unsent.single.summary;

    expect(read.open!.startedAt, startedAt);
    expect(read.open!.startedAt.isUtc, isTrue);
    expect(summary.endedAt, DateTime.utc(2026, 10, 23, 17, 30));
    expect(summary.endedAt.isUtc, isTrue);
  });

  test('should refuse another version or another shape', () {
    for (final json in [
      {...stored, 'version': 3},
      {'version': 2, 'round': null},
      {'version': 1},
      [stored],
      {'version': 2, 'round': 'round-1', 'unsent': <Object?>[]},
      {'version': 2, 'round': null, 'unsent': 'none'},
    ]) {
      expect(
        () => roundsFromJson(json),
        throwsFormatException,
        reason: '$json',
      );
    }
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
        () => roundsFromJson(storedWith(key, value)),
        throwsFormatException,
        reason: '$key: $value',
      );
    }
    expect(
      roundsFromJson(storedWith('housesVisited', 0)).open!.housesVisited,
      0,
    );
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
        () => roundsFromJson(storedWith('donations', [don])),
        throwsFormatException,
        reason: '$don',
      );
    }
  });

  test('should refuse a tournée not yet sent it cannot read', () {
    for (final (key, value) in [
      ('sector', ' '),
      ('campaign', 1999),
      ('refused', 'yes'),
      ('summary', null),
    ]) {
      expect(
        () => roundsFromJson(unsentWith({...storedRefused, key: value})),
        throwsFormatException,
        reason: '$key: $value',
      );
    }
    for (final (key, value) in [
      ('id', ''),
      ('startedAt', 'vendredi'),
      ('endedAt', null),
      ('housesVisited', -1),
      ('free', -1),
      ('cash', {'count': -1, 'cents': 0}),
      ('cheque', {'count': 0, 'cents': -1}),
      ('card', {'count': 1}),
    ]) {
      expect(
        () => roundsFromJson(summaryWith(key, value)),
        throwsFormatException,
        reason: 'summary $key: $value',
      );
    }
  });

  test('should take figures of 0 in a tournée not yet sent', () {
    final summary = roundsFromJson(summaryWith('housesVisited', 0))
        .unsent
        .single
        .summary;
    final free = roundsFromJson(summaryWith('free', 0)).unsent.single;
    final empty = roundsFromJson(summaryWith('cash', {'count': 0, 'cents': 0}))
        .unsent
        .single;

    expect(summary.housesVisited, 0);
    expect(free.summary.totals.free, 0);
    expect(empty.summary.totals.cash, MethodTotal.none);
  });

  group('the dons of a tournée not yet sent (#168)', () {
    final withDons = UnsentRound(
      sector: sector49Id,
      campaign: year2026,
      summary: round.validate(endedAt).summary,
    );
    final storedDons = [
      {'method': 'cash', 'cents': 750},
      {'free': true},
      {'method': 'cheque', 'cents': 2000},
      {'method': 'card', 'cents': 1000},
    ];

    test('should write them in order, with no house nor time', () {
      final json = roundsToJson((open: null, unsent: [withDons]));

      final summary =
          ((json['unsent']! as List<Object?>).single!
                  as Map<String, Object?>)['summary']!
              as Map<String, Object?>;
      expect(summary['donations'], storedDons);
      expect(roundsFromJson(json).unsent.single, withDons);
    });

    test('should write none for a summary without a list', () {
      final summary = (storedRefused['summary']! as Map<String, Object?>).keys;

      expect(summary, isNot(contains('donations')));
      expect(roundsFromJson(stored).unsent.first.summary.donations, isNull);
    });

    test('should refuse dons it cannot read', () {
      for (final value in [
        'cash:750',
        [
          {'method': 'gold', 'cents': 750},
        ],
        [
          {'method': 'cash', 'cents': 0},
        ],
      ]) {
        expect(
          () => roundsFromJson(summaryWith('donations', value)),
          throwsFormatException,
          reason: '$value',
        );
      }
    });

    test('should read an empty list as a list of no don', () {
      expect(
        roundsFromJson(summaryWith('donations', <Object?>[]))
            .unsent
            .single
            .summary
            .donations,
        isEmpty,
      );
    });
  });

  group('the house each don of the tournée on was noted from (#169)', () {
    final lilas = StreetId('rue-des-lilas');
    final threeBis = DonationOrigin(street: lilas, number: n('3bis'));
    final door51 = DonationOrigin(
      street: lilas,
      number: n('8'),
      door: DwellingKey(escA, 5, d('51')),
    );
    final linked = newRound()
        .add(cash(2000), from: threeBis)
        .add(cheque(500))
        .add(offered, from: door51);
    final storedLinked = {
      ...storedRound,
      'housesVisited': 0,
      'donations': [
        {
          'method': 'cash',
          'cents': 2000,
          'from': {'street': 'rue-des-lilas', 'number': '3bis'},
        },
        {'method': 'cheque', 'cents': 500},
        {
          'free': true,
          'from': {'street': 'rue-des-lilas', 'number': '8', 'door': 'A5-51'},
        },
      ],
    };

    test('should write the house or door beside its don, none for a don '
        'without one', () {
      expect(roundsToJson((open: linked, unsent: const [])), {
        'version': 2,
        'round': storedLinked,
        'unsent': <Object?>[],
      });
    });

    test('should read the links back', () {
      final read = roundsFromJson({
        'version': 2,
        'round': storedLinked,
        'unsent': <Object?>[],
      });

      expect(read.open, linked);
      expect(read.open!.origins, [threeBis, null, door51]);
    });

    test('should read a tournée kept before #169 as linking no don', () {
      expect(roundsFromJson(stored).open!.origins, [null, null, null, null]);
    });

    test('should keep no link in a tournée validated', () {
      final json = roundsToJson((
        open: null,
        unsent: [linked.validate(endedAt)],
      ));
      final summary =
          ((json['unsent']! as List<Object?>).single!
                  as Map<String, Object?>)['summary']!
              as Map<String, Object?>;

      expect(summary['donations'], [
        {'method': 'cash', 'cents': 2000},
        {'method': 'cheque', 'cents': 500},
        {'free': true},
      ]);
    });

    test('should refuse a link it cannot read', () {
      for (final from in [
        'rue-des-lilas',
        {'street': 'rue-des-lilas'},
        {'number': '3'},
        {'street': ' ', 'number': '3'},
        {'street': 'rue-des-lilas', 'number': 'bis'},
        {'street': 'rue-des-lilas', 'number': '8', 'door': 'A5'},
        {'street': 'rue-des-lilas', 'number': '8', 'door': 51},
      ]) {
        expect(
          () => roundsFromJson(
            storedWith('donations', [
              {'method': 'cash', 'cents': 2000, 'from': from},
            ]),
          ),
          throwsFormatException,
          reason: '$from',
        );
      }
    });
  });
}
