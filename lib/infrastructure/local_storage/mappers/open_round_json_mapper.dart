// Translation between the phone's tournées (PLAN §6.3) and the JSON it
// keeps for them in `open_round.json`. Pure functions: no file here, so
// they are tested alone.
//
// The schema, version 2 (#143):
//
//   { version: 2,
//     round: { id, sector, campaign: 2026,
//              startedAt: "2026-10-24T12:05:00.000Z",
//              housesVisited: 23,
//              donations: [ { method: "cash" | "cheque" | "card",
//                             cents: 750 }
//                         | { free: true }, … ] }
//            | null,                        ← no tournée on
//     unsent: [ { sector, campaign: 2026, refused: false,
//                 summary: { id, startedAt, endedAt, housesVisited, free,
//                            cash: { count, cents }, cheque: …, card: … } },
//               … ] }                       ← validated, not yet sent
//
// Version 1 (before #143) had no `unsent`: it is still read, as none.
//
// The dons carry no house and no time, on purpose (PLAN §8.3). Methods
// under fixed names, so renaming the Dart enum never changes what is on
// the phone. Every value goes through the domain's checks.
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The schema version this code writes.
const storedRoundsVersion = 2;

/// The version before the tournées not yet sent; still read.
const _firstVersion = 1;

const _cash = 'cash';
const _cheque = 'cheque';
const _card = 'card';

/// What `open_round.json` holds: the tournée on (null for none) and the
/// validated tournées not yet sent, in the order they were validated. A
/// record: two with equal fields are equal.
typedef StoredRounds = ({Round? open, List<UnsentRound> unsent});

/// The stored form of [rounds].
Map<String, Object?> roundsToJson(StoredRounds rounds) => {
  'version': storedRoundsVersion,
  'round': switch (rounds.open) {
    null => null,
    final round => {
      'id': round.id.value,
      'sector': round.sector.value,
      'campaign': round.campaign.value,
      'startedAt': _time(round.startedAt),
      'housesVisited': round.housesVisited,
      'donations': [
        for (final donation in round.donations) _donationToJson(donation),
      ],
    },
  },
  'unsent': [for (final round in rounds.unsent) _unsentToJson(round)],
};

String _time(DateTime time) => time.toUtc().toIso8601String();

Map<String, Object?> _donationToJson(Donation donation) => switch (donation) {
  PaidDonation(:final method, :final amount) => {
    'method': switch (method) {
      PaymentMethod.cash => _cash,
      PaymentMethod.cheque => _cheque,
      PaymentMethod.card => _card,
    },
    'cents': amount.cents,
  },
  FreeCalendar() => {'free': true},
};

Map<String, Object?> _unsentToJson(UnsentRound round) {
  final summary = round.summary;
  Map<String, Object?> total(MethodTotal total) => {
    'count': total.count,
    'cents': total.cents,
  };
  return {
    'sector': round.sector.value,
    'campaign': round.campaign.value,
    'refused': switch (round.state) {
      UnsentState.waiting => false,
      UnsentState.refused => true,
    },
    'summary': {
      'id': summary.id.value,
      'startedAt': _time(summary.startedAt),
      'endedAt': _time(summary.endedAt),
      'housesVisited': summary.housesVisited,
      'free': summary.totals.free,
      'cash': total(summary.totals.cash),
      'cheque': total(summary.totals.cheque),
      'card': total(summary.totals.card),
    },
  };
}

/// The tournées read from [json] as `jsonDecode` gives it. Throws a
/// [FormatException] when it is not a version 1 or 2 file, or when a value
/// breaks the domain's rules.
StoredRounds roundsFromJson(Object? json) => switch (json) {
  {
    'version': storedRoundsVersion,
    'round': final Object? round,
    'unsent': final List<Object?> unsent,
  } =>
    (
      open: round == null ? null : _roundFromJson(round),
      unsent: [for (final entry in unsent) _unsentFromJson(entry)],
    ),
  {'version': _firstVersion, 'round': final Object? round} => (
    open: round == null ? null : _roundFromJson(round),
    unsent: const <UnsentRound>[],
  ),
  _ => throw FormatException('Not the tournées of the phone: $json'),
};

Round _roundFromJson(Object round) {
  if (round
      case {
        'id': final String id,
        'sector': final String sector,
        'campaign': final int campaign,
        'startedAt': final String startedAt,
        'housesVisited': final int housesVisited,
        'donations': final List<Object?> donations,
      }
      when id.trim().isNotEmpty &&
          sector.trim().isNotEmpty &&
          housesVisited >= 0) {
    return Round.restore(
      id: RoundId(id),
      sector: SectorId(sector),
      campaign: _valid(CampaignYear.create(campaign), round),
      // `DateTime.parse` throws a FormatException on a bad date itself.
      startedAt: DateTime.parse(startedAt).toUtc(),
      housesVisited: housesVisited,
      donations: [
        for (final donation in donations) _donationFromJson(donation),
      ],
    );
  }
  throw FormatException('Not a tournée: $round');
}

Donation _donationFromJson(Object? json) => switch (json) {
  {'free': true} => const Donation.free(),
  {'method': final String method, 'cents': final int cents} => Donation.paid(
    switch (method) {
      _cash => PaymentMethod.cash,
      _cheque => PaymentMethod.cheque,
      _card => PaymentMethod.card,
      _ => throw FormatException('Not a payment method: $method'),
    },
    _valid(Amount.create(cents), json),
  ),
  _ => throw FormatException('Not a don: $json'),
};

UnsentRound _unsentFromJson(Object? json) {
  if (json
      case {
        'sector': final String sector,
        'campaign': final int campaign,
        'refused': final bool refused,
        'summary': {
          'id': final String id,
          'startedAt': final String startedAt,
          'endedAt': final String endedAt,
          'housesVisited': final int housesVisited,
          'free': final int free,
          'cash': final Object? cash,
          'cheque': final Object? cheque,
          'card': final Object? card,
        },
      }
      when sector.trim().isNotEmpty &&
          id.trim().isNotEmpty &&
          housesVisited >= 0 &&
          free >= 0) {
    return UnsentRound(
      sector: SectorId(sector),
      campaign: _valid(CampaignYear.create(campaign), json),
      summary: RoundSummary(
        id: RoundId(id),
        startedAt: DateTime.parse(startedAt).toUtc(),
        endedAt: DateTime.parse(endedAt).toUtc(),
        housesVisited: housesVisited,
        totals: DonationTotals(
          cash: _totalFromJson(cash),
          cheque: _totalFromJson(cheque),
          card: _totalFromJson(card),
          free: free,
        ),
      ),
      state: refused ? UnsentState.refused : UnsentState.waiting,
    );
  }
  throw FormatException('Not a tournée not yet sent: $json');
}

MethodTotal _totalFromJson(Object? json) => switch (json) {
  {'count': final int count, 'cents': final int cents}
      when count >= 0 && cents >= 0 =>
    MethodTotal(count: count, cents: cents),
  _ => throw FormatException('Not a total: $json'),
};

/// The value of [result], or a [FormatException] naming [json].
T _valid<T, F>(Result<T, F> result, Object json) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw FormatException('$failure in $json'),
};
