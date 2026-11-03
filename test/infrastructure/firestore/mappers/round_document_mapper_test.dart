import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/round_document_mapper.dart';

import '../../../domain/round/round_fixtures.dart';

/// A tournée of 3 houses, 2 dons in cash, 1 by cheque, 1 by card and 2
/// calendars given for free.
final summary = newRound()
    .visited()
    .visited()
    .visited()
    .add(cash(1000))
    .add(cash(750))
    .add(cheque(2000))
    .add(card(500))
    .add(offered)
    .add(offered)
    .validate(endedAt);

/// The document of [summary].
Map<String, Object?> document() => {
  'startedAt': Timestamp.fromDate(startedAt),
  'endedAt': Timestamp.fromDate(endedAt),
  'housesVisited': 3,
  'free': 2,
  'cash': {'count': 2, 'cents': 1750},
  'cheque': {'count': 1, 'cents': 2000},
  'card': {'count': 1, 'cents': 500},
};

void main() {
  test('should write the summary with no member and no don', () {
    expect(roundToDocument(summary), document());
  });

  test('should read back the summary it writes, in UTC', () {
    final read = roundFromDocument('round-1', roundToDocument(summary));

    expect(read, summary);
    expect(read.id, RoundId('round-1'));
    expect(read.startedAt, DateTime.utc(2026, 10, 24, 12, 5));
    expect(read.startedAt.isUtc, isTrue);
    expect(read.endedAt, DateTime.utc(2026, 10, 24, 16, 20));
    expect(read.housesVisited, 3);
    expect(read.totals.cash, MethodTotal(count: 2, cents: 1750));
    expect(read.totals.cheque, MethodTotal(count: 1, cents: 2000));
    expect(read.totals.card, MethodTotal(count: 1, cents: 500));
    expect(read.totals.free, 2);
  });

  test('should read a tournée with nothing in it', () {
    final empty = newRound().validate(endedAt);

    expect(roundFromDocument('round-1', roundToDocument(empty)), empty);
  });

  test('should read the id of the document as the round id', () {
    expect(roundFromDocument('Ab3xYz', document()).id, RoundId('Ab3xYz'));
  });

  group('should refuse a document', () {
    void refuses(String why, Map<String, Object?> data, {String id = 'r1'}) =>
        test(why, () {
          expect(
            () => roundFromDocument(id, data),
            throwsA(isA<FormatException>()),
          );
        });

    for (final field in document().keys) {
      refuses('without $field', document()..remove(field));
    }
    refuses('with a blank id', document(), id: ' ');
    refuses(
      'whose start is not a time',
      document()..['startedAt'] = '2026-10-24',
    );
    refuses('whose end is not a time', document()..['endedAt'] = 12);
    refuses(
      'whose houses are not a whole number',
      document()..['housesVisited'] = 3.5,
    );
    refuses('with -1 house', document()..['housesVisited'] = -1);
    refuses('with -1 free calendar', document()..['free'] = -1);
    refuses('whose cash is not a total', document()..['cash'] = 1750);
    refuses(
      'with a total of -1 don',
      document()..['cheque'] = {'count': -1, 'cents': 2000},
    );
    refuses(
      'with a total of -1 cent',
      document()..['card'] = {'count': 1, 'cents': -1},
    );
    refuses('with a total without cents', document()..['card'] = {'count': 1});
  });

  test('should read 0 houses, 0 free and totals of 0 as none', () {
    final data = document()
      ..['housesVisited'] = 0
      ..['free'] = 0
      ..['cash'] = {'count': 0, 'cents': 0};

    final read = roundFromDocument('round-1', data);

    expect(read.housesVisited, 0);
    expect(read.totals.free, 0);
    expect(read.totals.cash, MethodTotal.none);
    expect(read, isA<RoundSummary>());
  });

  test('should read every summary of the documents, in their order', () {
    final empty = newRound().validate(endedAt);

    expect(
      roundsFromDocuments({
        'round-1': roundToDocument(summary),
        'round-2': roundToDocument(empty),
      }),
      [
        summary,
        RoundSummary(
          id: RoundId('round-2'),
          startedAt: empty.startedAt,
          endedAt: empty.endedAt,
          housesVisited: 0,
          totals: DonationTotals.none,
        ),
      ],
    );
  });

  test('should leave out a document it cannot read, keeping the others', () {
    expect(
      roundsFromDocuments({
        'round-0': document()..remove('free'),
        'round-1': roundToDocument(summary),
      }),
      [summary],
    );
  });
}
