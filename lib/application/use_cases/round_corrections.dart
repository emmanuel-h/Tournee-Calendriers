import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

// Correcting a validated tournée and marking its forgotten houses (PLAN
// §5.20, #168), from « Collecte ». Any active member of the secteur, or an
// admin, may (the server's rules check it). Everything here works offline:
// the ledger keeps each write on the phone and sends it later.

/// Which validated tournée: the tournée [round] of [campaign] of
/// [sector]. A record: two with the same fields are equal.
typedef RoundPlace = ({SectorId sector, CampaignYear campaign, RoundId round});

/// Which house or door was forgotten: the house [number] of the street
/// [street], or its door [door] when it is a building.
typedef ForgottenPlace = ({
  StreetId street,
  HouseNumber number,
  DwellingKey? door,
});

/// Why a validated tournée could not be changed: it is not on the phone,
/// or it refused the command for a [reason] of type [F].
sealed class RoundCommandFailure<F> {
  const RoundCommandFailure();
}

/// No validated tournée has that id here (deleted with its campaign, or
/// not read yet).
final class RoundNotFound<F> extends RoundCommandFailure<F> {
  const RoundNotFound();

  @override
  bool operator ==(Object other) => other is RoundNotFound<F>;

  @override
  int get hashCode => (RoundNotFound).hashCode;

  @override
  String toString() => 'RoundNotFound';
}

/// The tournée refused the command, for [reason].
final class RoundCommandRefused<F> extends RoundCommandFailure<F> {
  const RoundCommandRefused(this.reason);

  final F reason;

  @override
  bool operator ==(Object other) =>
      other is RoundCommandRefused<F> && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'RoundCommandRefused($reason)';
}

/// The steps the round use cases share, as `runOnStreet` for streets: find
/// the tournée of [place], run [command] on it, hand the change it made to
/// [write], and return the tournée as it now is.
Future<Result<RoundSummary, RoundCommandFailure<F>>> _runOnRound<C, F>(
  RoundLedger ledger,
  RoundPlace place,
  Result<(RoundSummary, C), F> Function(RoundSummary summary) command,
  Future<void> Function(C change) write,
) async {
  final summary = await ledger.find(place.sector, place.campaign, place.round);
  if (summary == null) return Err(RoundNotFound<F>());
  switch (command(summary)) {
    case Err(:final failure):
      return Err(RoundCommandRefused(failure));
    case Ok(value: (final changed, final change)):
      await write(change);
      return Ok(changed);
  }
}

/// « Enregistrer » of « Corriger la tournée », Don par don: the tournée's
/// list becomes [donations] and its totals are worked out again from it.
/// Returns the tournée corrected.
final class CorrectRoundDonations {
  const CorrectRoundDonations(this._ledger, this._clock);

  final RoundLedger _ledger;
  final Clock _clock;

  Future<Result<RoundSummary, RoundCommandFailure<CorrectionFailure>>> call(
    RoundPlace place,
    List<Donation> donations,
  ) {
    final at = _clock.now();
    return _runOnRound(
      _ledger,
      place,
      (summary) => summary.correctDonations(donations, at: at),
      (change) =>
          _ledger.correct(place.sector, place.campaign, place.round, change),
    );
  }
}

/// « Enregistrer » of « Corriger la tournée », Totaux: the tournée's totals
/// become [totals], its list left as it is. Returns the tournée corrected.
final class CorrectRoundTotals {
  const CorrectRoundTotals(this._ledger, this._clock);

  final RoundLedger _ledger;
  final Clock _clock;

  Future<Result<RoundSummary, RoundCommandFailure<CorrectionFailure>>> call(
    RoundPlace place,
    DonationTotals totals,
  ) {
    final at = _clock.now();
    return _runOnRound(
      _ledger,
      place,
      (summary) => summary.correctTotals(totals, at: at),
      (change) =>
          _ledger.correct(place.sector, place.campaign, place.round, change),
    );
  }
}

/// « Ignorer » of « ⚠ 1 maison à marquer »: one fewer to mark, asked
/// nothing. Returns the tournée as it now is.
final class IgnoreForgottenHouse {
  const IgnoreForgottenHouse(this._ledger);

  final RoundLedger _ledger;

  Future<Result<RoundSummary, RoundCommandFailure<NoHouseToMark>>> call(
    RoundPlace place,
  ) => _runOnRound(
    _ledger,
    place,
    (summary) => summary.settleForgottenHouse(ForgottenHouse.ignored),
    (settled) => _ledger.settleForgottenHouse(
      place.sector,
      place.campaign,
      place.round,
      settled,
    ),
  );
}

/// Why a forgotten house could not be marked.
enum MarkForgottenFailure {
  /// The tournée is gone, or has no house left to mark (marked or ignored
  /// meanwhile, on another phone).
  nothingToMark,

  /// The street, the house or the door is no longer there.
  houseGone,

  /// The house or door is ✓ or ⊘ already (« N° 9 : déjà marquée ✓. »).
  alreadyVisited,
}

/// A tap in « Touchez la maison oubliée » (PLAN §5.20): the house or door
/// [house] is marked ✓ with no tournée on (the only exception to #122), as
/// the member of this phone now, and the tournée [place] counts one more
/// house visited and one fewer to mark. Returns the street's change.
///
/// The tournée on, if any, is not told: the house belongs to the validated
/// one.
final class MarkForgottenHouse {
  const MarkForgottenHouse(
    this._ledger,
    this._streets,
    this._clock,
    this._identity,
  );

  final RoundLedger _ledger;
  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  Future<Result<StreetChange, MarkForgottenFailure>> call(
    RoundPlace place,
    ForgottenPlace house,
  ) async {
    // The tournée first: a house is marked only while one is left to.
    final summary = await _ledger.find(
      place.sector,
      place.campaign,
      place.round,
    );
    if (summary == null ||
        summary.settleForgottenHouse(ForgottenHouse.marked) is Err) {
      return const Err(MarkForgottenFailure.nothingToMark);
    }
    final by = _identity.currentMember;
    final at = _clock.now();
    final marked = await runOnStreet(
      _streets,
      house.street,
      (street) =>
          street.markForgotten(house.number, door: house.door, by: by, at: at),
    );
    switch (marked) {
      case Err(failure: StreetNotFound()):
      case Err(failure: CommandRefused(reason: ForgottenMarkFailure.notFound)):
        return const Err(MarkForgottenFailure.houseGone);
      case Err(
        failure: CommandRefused(reason: ForgottenMarkFailure.alreadyVisited),
      ):
        return const Err(MarkForgottenFailure.alreadyVisited);
      case Ok(value: final change):
        await _ledger.settleForgottenHouse(
          place.sector,
          place.campaign,
          place.round,
          ForgottenHouse.marked,
        );
        return Ok(change);
    }
  }
}
