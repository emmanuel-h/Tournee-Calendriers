import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, Timestamp;
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
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
    .validate(endedAt)
    .summary;

/// The dons of [summary], as stored.
const storedDons = [
  'cash:1000',
  'cash:750',
  'cheque:2000',
  'card:500',
  'free',
  'free',
];

/// The document of [summary] without its dons: one validated before #168.
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
  test('should write the summary and its dons in order, with no member', () {
    expect(roundToDocument(summary), {...document(), 'dons': storedDons});
  });

  test('should write no dons for a summary without a list', () {
    expect(
      roundToDocument(roundFromDocument('round-1', document())),
      document(),
    );
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
    final empty = newRound().validate(endedAt).summary;

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
    final empty = newRound().validate(endedAt).summary;

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
          donations: const [],
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

  group('the dons, the corrections and the houses to mark (#168)', () {
    test('should read a document without them as one validated before', () {
      final read = roundFromDocument('round-1', document());

      expect(read.donations, isNull);
      expect(read.correctedAt, isNull);
      expect(read.housesToMark, 0);
    });

    test('should read the dons in order, the correction and the houses to '
        'mark', () {
      final read = roundFromDocument('round-1', {
        ...document(),
        'dons': storedDons,
        'correctedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 25, 9)),
        'housesToMark': 2,
      });

      expect(read.donations, [
        cash(1000),
        cash(750),
        cheque(2000),
        card(500),
        offered,
        offered,
      ]);
      expect(read.correctedAt, DateTime.utc(2026, 10, 25, 9));
      expect(read.correctedAt!.isUtc, isTrue);
      expect(read.housesToMark, 2);
    });

    test('should read the largest don and an empty list', () {
      expect(
        roundFromDocument('r', {
          ...document(),
          'dons': ['card:100000'],
        }).donations,
        [card(100000)],
      );
      expect(
        roundFromDocument('r', {...document(), 'dons': <Object?>[]}).donations,
        isEmpty,
      );
    });

    for (final (why, field, value) in [
      ('dons that are not a list', 'dons', 'cash:1000'),
      ('a don of an unknown method', 'dons', ['gold:1000']),
      ('a don of no money', 'dons', ['cash:0']),
      ('a don past 1 000 €', 'dons', ['cash:100001']),
      ('a don without cents', 'dons', ['cash:']),
      ('a don with a sign', 'dons', ['cash:+5']),
      ('a don that is not a text', 'dons', [1000]),
      ('a correction that is not a time', 'correctedAt', '2026-10-25'),
      ('-1 house to mark', 'housesToMark', -1),
      ('houses to mark that are not a number', 'housesToMark', '1'),
    ]) {
      test('should refuse $why', () {
        expect(
          () => roundFromDocument('r', {...document(), field: value}),
          throwsFormatException,
        );
      });
    }

    test('should write a correction of the totals only, the houses it adds '
        'as an increment', () {
      final totals = DonationTotals.of([cash(1000), offered]);

      expect(
        correctionToUpdate(
          RoundCorrected(
            totals: totals,
            donations: null,
            correctedAt: DateTime.utc(2026, 10, 25, 9),
            housesAdded: 2,
          ),
        ),
        {
          'free': 1,
          'cash': {'count': 1, 'cents': 1000},
          'cheque': {'count': 0, 'cents': 0},
          'card': {'count': 0, 'cents': 0},
          'correctedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 25, 9)),
          'housesToMark': FieldValue.increment(2),
        },
      );
    });

    test('should write the new list of a correction don by don', () {
      final update = correctionToUpdate(
        RoundCorrected(
          totals: DonationTotals.of([card(500)]),
          donations: [card(500)],
          correctedAt: DateTime.utc(2026, 10, 25, 9),
          housesAdded: 0,
        ),
      );

      expect(update['dons'], ['card:500']);
      expect(update['housesToMark'], FieldValue.increment(0));
      expect(update.keys, isNot(contains('housesVisited')));
      expect(update.keys, isNot(contains('startedAt')));
    });

    test('should take one off the houses to mark, and add one visited when '
        'marked', () {
      expect(forgottenHouseToUpdate(ForgottenHouse.marked), {
        'housesToMark': FieldValue.increment(-1),
        'housesVisited': FieldValue.increment(1),
      });
      expect(forgottenHouseToUpdate(ForgottenHouse.ignored), {
        'housesToMark': FieldValue.increment(-1),
      });
    });
  });
}
