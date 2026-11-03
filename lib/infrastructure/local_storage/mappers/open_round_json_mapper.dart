// Translation between the tournée on (PLAN §6.3) and the JSON the phone
// keeps for it. Pure functions: no file here, so they are tested alone.
//
// The schema, version 1:
//
//   { version: 1,
//     round: { id, sector, campaign: 2026,
//              startedAt: "2026-10-24T12:05:00.000Z",
//              housesVisited: 23,
//              donations: [ { method: "cash" | "cheque" | "card",
//                             cents: 750 }
//                         | { free: true }, … ] }
//            | null }                       ← no tournée on
//
// The dons carry no house and no time, on purpose (PLAN §8.3). Methods
// under fixed names, so renaming the Dart enum never changes what is on
// the phone. Every value goes through the domain's checks.
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The schema version this code writes and reads.
const storedOpenRoundVersion = 1;

const _cash = 'cash';
const _cheque = 'cheque';
const _card = 'card';

/// The stored form of [round], the tournée on; null for none.
Map<String, Object?> openRoundToJson(Round? round) => {
  'version': storedOpenRoundVersion,
  'round': round == null
      ? null
      : {
          'id': round.id.value,
          'sector': round.sector.value,
          'campaign': round.campaign.value,
          'startedAt': round.startedAt.toUtc().toIso8601String(),
          'housesVisited': round.housesVisited,
          'donations': [
            for (final donation in round.donations) _donationToJson(donation),
          ],
        },
};

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

/// The tournée on read from [json] as `jsonDecode` gives it; null for none.
/// Throws a [FormatException] when it is not a version 1 file, or when a
/// value breaks the domain's rules.
Round? openRoundFromJson(Object? json) {
  if (json case {'version': storedOpenRoundVersion, 'round': final round}) {
    return round == null ? null : _roundFromJson(round);
  }
  throw FormatException('Not a tournée on: $json');
}

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

/// The value of [result], or a [FormatException] naming [json].
T _valid<T, F>(Result<T, F> result, Object json) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw FormatException('$failure in $json'),
};
