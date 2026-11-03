// Translation between a validated tournée's RoundSummary and its Firestore
// document (PLAN §6.2). Pure functions, tested alone.
//
//   sectors/{id}/campaigns/{year}/rounds/{roundId}
//     { startedAt: time, endedAt: time, housesVisited: 23, free: 2,
//       cash: { count, cents }, cheque: { count, cents },
//       card: { count, cents } }
//
// No member and no don, on purpose: nothing else of a tournée leaves the
// phone (PLAN §8.3). The document id is the round's id, so a summary sent
// twice is still one document.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/stored_values.dart';

/// The document `rounds/{roundId}` of [summary]; its id is the document's.
Map<String, Object?> roundToDocument(RoundSummary summary) => {
  'startedAt': Timestamp.fromDate(summary.startedAt),
  'endedAt': Timestamp.fromDate(summary.endedAt),
  'housesVisited': summary.housesVisited,
  'free': summary.totals.free,
  'cash': _totalToEntry(summary.totals.cash),
  'cheque': _totalToEntry(summary.totals.cheque),
  'card': _totalToEntry(summary.totals.card),
};

Map<String, Object?> _totalToEntry(MethodTotal total) => {
  'count': total.count,
  'cents': total.cents,
};

/// The summary stored in `rounds/[id]` as [data].
///
/// Throws a [FormatException] when [data] is not what this code writes:
/// a field missing or of another type, or a negative figure.
RoundSummary roundFromDocument(String id, Map<String, Object?> data) {
  if (data
      case {
        'startedAt': final Object? startedAt,
        'endedAt': final Object? endedAt,
        'housesVisited': final int housesVisited,
        'free': final int free,
        'cash': final Object? cash,
        'cheque': final Object? cheque,
        'card': final Object? card,
      }
      when housesVisited >= 0 && free >= 0) {
    return RoundSummary(
      id: identifier(id, RoundId.new),
      startedAt: timeFrom(startedAt),
      endedAt: timeFrom(endedAt),
      housesVisited: housesVisited,
      totals: DonationTotals(
        cash: _totalFrom(cash),
        cheque: _totalFrom(cheque),
        card: _totalFrom(card),
        free: free,
      ),
    );
  }
  throw FormatException('Not a tournée summary document', id);
}

MethodTotal _totalFrom(Object? entry) => switch (entry) {
  {'count': final int count, 'cents': final int cents}
      when count >= 0 && cents >= 0 =>
    MethodTotal(count: count, cents: cents),
  _ => throw FormatException('Not a stored total', entry),
};

/// The summaries of the documents of `rounds/`, each document's data by id,
/// leaving out those [roundFromDocument] cannot read: one unreadable
/// tournée (written by a newer app) must not hide the whole « Collecte ».
List<RoundSummary> roundsFromDocuments(
  Map<String, Map<String, Object?>> documents,
) => [
  for (final MapEntry(:key, :value) in documents.entries)
    ?_readable(key, value),
];

RoundSummary? _readable(String id, Map<String, Object?> data) {
  try {
    return roundFromDocument(id, data);
  } on FormatException {
    return null;
  }
}
