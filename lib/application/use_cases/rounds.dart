import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/application/use_cases/calendars.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/round/collecte.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

// The tournées (PLAN §5.13): one outing of the member of this phone, its
// dons kept on the phone until it is validated, then only its summary sent
// to the secteur. Everything here works offline, cold start included.

/// Why « Commencer une tournée » cannot start one.
enum StartRoundFailure {
  /// No secteur is open: the phone's own streets (M1) have no tournée.
  noSectorOpen,

  /// The open secteur is one an admin visits without being in its team
  /// (PLAN §5.12): its tournées are the team's.
  notInTheTeam,

  /// A tournée is already on, here or in another secteur: one at a time on
  /// a phone.
  alreadyOn,
}

/// No tournée is on: it was validated meanwhile (another screen), or never
/// started.
final class NoRoundOn {
  const NoRoundOn();

  @override
  bool operator ==(Object other) => other is NoRoundOn;

  @override
  int get hashCode => (NoRoundOn).hashCode;

  @override
  String toString() => 'NoRoundOn';
}

/// Why a don of the tournée on cannot be changed or removed.
enum DonationEditFailure {
  /// No tournée is on (see [NoRoundOn]).
  noRoundOn,

  /// No don at that place: « Dons de la tournée » showed an older list.
  noSuchDonation,
}

/// « Commencer une tournée »: a tournée of the open secteur's current
/// campaign starts now, for the member of this phone. Returns it, or why it
/// cannot start.
final class StartRound {
  const StartRound(this._rounds, this._mySectors, this._clock, this._ids);

  final OpenRoundStore _rounds;
  final MySectorsStore _mySectors;
  final Clock _clock;
  final IdGenerator _ids;

  Future<Result<Round, StartRoundFailure>> call() async {
    final sector = _mySectors.mySectors.current;
    if (sector == null) return const Err(StartRoundFailure.noSectorOpen);
    switch (sector.status) {
      case MemberStatus.active:
        break;
      // The open secteur is never a pending request (`MySectors`), so
      // `pending` is refused here only for the `switch` to name it.
      case MemberStatus.visiting || MemberStatus.pending:
        return const Err(StartRoundFailure.notInTheTeam);
    }
    if (_rounds.openRound != null) {
      return const Err(StartRoundFailure.alreadyOn);
    }
    final round = Round.start(
      id: RoundId(_ids.newId()),
      sector: sector.id,
      campaign: sector.campaign,
      at: _clock.now(),
    );
    await _rounds.save(round);
    return Ok(round);
  }
}

/// The tournée on now, then after each change, when it belongs to the
/// secteur [open] (the one the app shows); null otherwise. Accueil and the
/// street screen show its card only there (PLAN §5.13).
final class WatchOpenRound {
  const WatchOpenRound(this._rounds);

  final OpenRoundStore _rounds;

  Stream<Round?> call(SectorId? open) async* {
    Round? ifHere(Round? round) => round?.sector == open ? round : null;
    yield ifHere(_rounds.openRound);
    yield* _rounds.changes.map(ifHere);
  }
}

/// A don [AddDonation] added: the tournée with it (the don last), and the
/// calendar the house or door took with it, for « Annuler ».
final class AddedDonation {
  const AddedDonation({required this.round, this.calendar});

  final Round round;

  /// The change giving the house or door one calendar more; null for a don
  /// given without a house (« Dons de la tournée »), or when the house was
  /// no longer done (a teammate changed it meanwhile: the money is still
  /// the tournée's).
  final StreetChange? calendar;

  @override
  bool operator ==(Object other) =>
      other is AddedDonation &&
      other.round == round &&
      other.calendar == calendar;

  @override
  int get hashCode => Object.hash(round, calendar);

  @override
  String toString() => 'AddedDonation($round, $calendar)';
}

/// A don joins the tournée on: « Valider » of « Nouveau don » (no house),
/// or « + Ajouter un don » on a house or door done ([calendarFor]), which
/// then took one calendar more (PLAN §5.6, #114). The don itself never
/// names the house (PLAN §8.3). Needs no network.
final class AddDonation {
  const AddDonation(this._rounds, this._streets, this._clock, this._identity);

  final OpenRoundStore _rounds;
  final StreetRepository _streets;
  final Clock _clock;
  final IdentityProvider _identity;

  /// The don first, then the calendar: the money is the tournée's whatever
  /// happened to the house. Nothing is stored without a tournée on.
  Future<Result<AddedDonation, NoRoundOn>> call(
    Donation donation, {
    CalendarPlace? calendarFor,
  }) async {
    final round = _rounds.openRound;
    if (round == null) return const Err(NoRoundOn());
    final changed = round.add(donation);
    await _rounds.save(changed);
    if (calendarFor == null) return Ok(AddedDonation(round: changed));
    final by = _identity.currentMember;
    final at = _clock.now();
    final calendar = await runOnStreet(
      _streets,
      calendarFor.street,
      (street) => street.addCalendar(
        calendarFor.number,
        door: calendarFor.door,
        by: by,
        at: at,
      ),
    );
    return Ok(
      AddedDonation(
        round: changed,
        calendar: switch (calendar) {
          Ok(:final value) => value,
          Err() => null,
        },
      ),
    );
  }
}

/// « Valider » of « Modifier le don »: the don at [index] (in the order
/// added, `Round.donations`) becomes [donation]. A house's calendars stay
/// as they are: dons know no house.
final class ChangeDonation {
  const ChangeDonation(this._rounds);

  final OpenRoundStore _rounds;

  Future<Result<Round, DonationEditFailure>> call(
    int index,
    Donation donation,
  ) => _editDonation(_rounds, (round) => round.replace(index, donation));
}

/// « Supprimer ce don »: the don at [index] (in the order added) goes.
final class RemoveDonation {
  const RemoveDonation(this._rounds);

  final OpenRoundStore _rounds;

  Future<Result<Round, DonationEditFailure>> call(int index) =>
      _editDonation(_rounds, (round) => round.remove(index));
}

/// The steps [ChangeDonation] and [RemoveDonation] share: run [edit] on the
/// tournée on and save what it makes.
Future<Result<Round, DonationEditFailure>> _editDonation(
  OpenRoundStore rounds,
  Result<Round, NoSuchDonation> Function(Round round) edit,
) async {
  final round = rounds.openRound;
  if (round == null) return const Err(DonationEditFailure.noRoundOn);
  switch (edit(round)) {
    case Err():
      return const Err(DonationEditFailure.noSuchDonation);
    case Ok(value: final changed):
      await rounds.save(changed);
      return Ok(changed);
  }
}

/// « Valider la tournée »: its summary goes to the secteur it started in
/// (queued while offline), then the phone forgets it and its dons. A
/// validated tournée is never changed. Returns the summary sent.
///
/// The summary is handed over before the tournée is forgotten: killed in
/// between, the tournée is still on at the next start, and validating it
/// again sends the same summary (same id), which the ledger keeps once.
final class ValidateRound {
  const ValidateRound(this._rounds, this._ledger, this._clock);

  final OpenRoundStore _rounds;
  final RoundLedger _ledger;
  final Clock _clock;

  Future<Result<RoundSummary, NoRoundOn>> call() async {
    final round = _rounds.openRound;
    if (round == null) return const Err(NoRoundOn());
    final summary = round.validate(_clock.now());
    await _ledger.record(round.sector, round.campaign, summary);
    await _rounds.clear();
    return Ok(summary);
  }
}

/// « Collecte 2026 » (PLAN §5.13): the validated tournées of [campaign] of
/// [sector] and their totals, now and again at each tournée validated, by
/// this phone or a teammate's. Read from the phone's copy first, so it
/// works offline. Never split per member: a summary names none.
final class WatchCollecte {
  const WatchCollecte(this._ledger);

  final RoundLedger _ledger;

  Stream<Collecte> call(SectorId sector, CampaignYear campaign) =>
      _ledger.watch(sector, campaign).map(Collecte.of);
}
