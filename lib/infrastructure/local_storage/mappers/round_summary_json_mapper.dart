// The JSON the phone keeps for a validated tournée (PLAN §6.3,
// `validated_rounds/`), until the secteur's ledger on Firestore takes it
// over (#110). A pure function: no file here, so it is tested alone.
//
// The schema, version 1, the fields of `rounds/{roundId}` (PLAN §6.2):
//
//   { version: 1,
//     startedAt: "2026-10-24T12:05:00.000Z", endedAt: "…",
//     housesVisited: 23, free: 2,
//     cash: { count, cents }, cheque: { count, cents }, card: { count, cents } }
//
// No member and no don, on purpose: nothing else leaves a tournée.
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';

/// The schema version this code writes.
const storedRoundSummaryVersion = 1;

/// The stored form of [summary]. Its id is the file's name.
Map<String, Object?> roundSummaryToJson(RoundSummary summary) => {
  'version': storedRoundSummaryVersion,
  'startedAt': summary.startedAt.toUtc().toIso8601String(),
  'endedAt': summary.endedAt.toUtc().toIso8601String(),
  'housesVisited': summary.housesVisited,
  'free': summary.totals.free,
  'cash': _totalToJson(summary.totals.cash),
  'cheque': _totalToJson(summary.totals.cheque),
  'card': _totalToJson(summary.totals.card),
};

Map<String, Object?> _totalToJson(MethodTotal total) => {
  'count': total.count,
  'cents': total.cents,
};
