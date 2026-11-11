import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/open_round_json_mapper.dart';

import '../../../domain/round/round_fixtures.dart';
import '../../../support/results.dart';

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
}
