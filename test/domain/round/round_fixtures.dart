// Dons and tournées of the 49 (CS Villefranche, location privacy), for the
// tests of the tournées (PLAN §5.13).
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../support/results.dart';

/// [cents] as an [Amount].
Amount cents(int cents) => valueOf(Amount.create(cents));

/// [amount] cents in cash.
Donation cash(int amount) => Donation.paid(PaymentMethod.cash, cents(amount));

/// [amount] cents by cheque.
Donation cheque(int amount) =>
    Donation.paid(PaymentMethod.cheque, cents(amount));

/// [amount] cents by card.
Donation card(int amount) => Donation.paid(PaymentMethod.card, cents(amount));

const offered = Donation.free();

final roundId = RoundId('round-1');
final sector49Id = SectorId('t49');
final year2026 = valueOf(CampaignYear.create(2026));

/// Saturday 24 October 2026, 14:05 in Villefranche (12:05 UTC).
final startedAt = DateTime.utc(2026, 10, 24, 12, 5);

/// The same day, 18:20 in Villefranche.
final endedAt = DateTime.utc(2026, 10, 24, 16, 20);

/// The tournée of the 49 started at [startedAt], nothing in it yet.
Round newRound() => Round.start(
  id: roundId,
  sector: sector49Id,
  campaign: year2026,
  at: startedAt,
);
