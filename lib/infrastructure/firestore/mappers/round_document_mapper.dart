// Translation between a validated tournée's RoundSummary and its Firestore
// document (PLAN §6.2). Pure functions, tested alone.
//
//   sectors/{id}/campaigns/{year}/rounds/{roundId}
//     { startedAt: time, endedAt: time, housesVisited: 23, free: 2,
//       cash: { count, cents }, cheque: { count, cents },
//       card: { count, cents },
//       dons: ["cash:1000", "free", "card:1500", …],   ← #168, in order
//       correctedAt: time,                             ← once corrected
//       housesToMark: 1 }                              ← once a correction
//                                                        added dons
//
// No member, and the dons name no house and no time, on purpose (PLAN
// §8.3). Each don is one short text, so the server's rules, which have no
// loops, check the whole list with one pattern (PLAN §8.2). The document
// id is the round's id, so a summary sent twice is still one document.
import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, Timestamp;
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/stored_values.dart';

const _cash = 'cash';
const _cheque = 'cheque';
const _card = 'card';
const _free = 'free';

/// The document `rounds/{roundId}` of [summary] as « Valider la tournée »
/// makes it, its id the document's: its figures and its dons, never a
/// correction (a summary is created only before any).
Map<String, Object?> roundToDocument(RoundSummary summary) => {
  'startedAt': Timestamp.fromDate(summary.startedAt),
  'endedAt': Timestamp.fromDate(summary.endedAt),
  'housesVisited': summary.housesVisited,
  ..._totalsToFields(summary.totals),
  if (summary.donations case final donations?)
    'dons': donationsToEntries(donations),
};

Map<String, Object?> _totalsToFields(DonationTotals totals) => {
  'free': totals.free,
  'cash': _totalToEntry(totals.cash),
  'cheque': _totalToEntry(totals.cheque),
  'card': _totalToEntry(totals.card),
};

Map<String, Object?> _totalToEntry(MethodTotal total) => {
  'count': total.count,
  'cents': total.cents,
};

/// The dons as stored: « cash:1000 », « cheque:500 », « card:1500 » or
/// « free », in the order added. Methods under fixed names, so renaming
/// the Dart enum never changes what is stored.
List<String> donationsToEntries(List<Donation> donations) => [
  for (final donation in donations)
    switch (donation) {
      PaidDonation(:final method, :final amount) =>
        '${switch (method) {
          PaymentMethod.cash => _cash,
          PaymentMethod.cheque => _cheque,
          PaymentMethod.card => _card,
        }}:${amount.cents}',
      FreeCalendar() => _free,
    },
];

/// The update [correction] makes (« Corriger la tournée »): only its own
/// fields, so start, end and houses visited stay as the server has them.
/// The houses it adds are an increment: those another phone left to mark,
/// or marked meanwhile, are kept.
Map<String, Object?> correctionToUpdate(RoundCorrected correction) => {
  ..._totalsToFields(correction.totals),
  if (correction.donations case final donations?)
    'dons': donationsToEntries(donations),
  'correctedAt': Timestamp.fromDate(correction.correctedAt),
  'housesToMark': FieldValue.increment(correction.housesAdded),
};

/// The update of a forgotten house [settled]: one fewer to mark, and one
/// more house visited when marked, both counted from what the server has.
Map<String, Object?> forgottenHouseToUpdate(ForgottenHouse settled) => {
  'housesToMark': FieldValue.increment(-1),
  if (settled == ForgottenHouse.marked)
    'housesVisited': FieldValue.increment(1),
};

/// The summary stored in `rounds/[id]` as [data].
///
/// Throws a [FormatException] when [data] is not what this code writes:
/// a field missing or of another type, a negative figure, or a don it
/// cannot read. A document written before #168 has no `dons` (a summary
/// without a list), no `correctedAt` and no `housesToMark` (none).
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
      donations: switch (data['dons']) {
        null => null,
        final List<Object?> entries => [
          for (final entry in entries) _donationFrom(entry),
        ],
        final other => throw FormatException('Not the dons', other),
      },
      correctedAt: switch (data['correctedAt']) {
        null => null,
        final Object at => timeFrom(at),
      },
      housesToMark: switch (data['housesToMark']) {
        null => 0,
        final int count when count >= 0 => count,
        final other => throw FormatException('Not houses to mark', other),
      },
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

/// A paid don as stored: its method, a colon, its cents.
final _paidEntry = RegExp(r'^(cash|cheque|card):(\d{1,6})$');

Donation _donationFrom(Object? entry) {
  if (entry == _free) return const Donation.free();
  final match = entry is String ? _paidEntry.firstMatch(entry) : null;
  if (match == null) throw FormatException('Not a stored don', entry);
  final amount = valid(Amount.create(int.parse(match[2]!)), 'don $entry');
  return Donation.paid(switch (match[1]) {
    _cash => PaymentMethod.cash,
    _cheque => PaymentMethod.cheque,
    _ => PaymentMethod.card,
  }, amount);
}

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
