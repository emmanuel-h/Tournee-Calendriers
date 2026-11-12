import 'dart:async';

import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/application/ports/open_round_store.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/application/use_cases/calendars.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/round/collecte.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

// The tournées (PLAN §5.13): one outing of the member of this phone, its
// dons kept on the phone until it is validated, then only its summary sent
// to the secteur. Everything here works offline, cold start included.

/// Why « Commencer une tournée » cannot start one.
enum StartRoundFailure {
  /// No secteur is open: a tournée is one of a secteur's outings.
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
/// cannot start. A tournée still on in a secteur the phone no longer has is
/// forgotten first, its dons with it (#162).
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
    if (_rounds.openRound case final on?) {
      // A tournée of a secteur the phone forgot (left, deleted, removed
      // from the team) can never be ended nor validated: its band shows
      // only in its secteur. It would block every tournée to come (#162).
      if (_mySectors.mySectors.find(on.sector) != null) {
        return const Err(StartRoundFailure.alreadyOn);
      }
      await _rounds.clear();
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
/// calendar the house or door took with it, for « Annuler », or why it
/// took none.
final class AddedDonation {
  const AddedDonation({
    required this.round,
    this.calendar,
    this.calendarRefused,
  });

  final Round round;

  /// The change giving the house or door one calendar more; null for a don
  /// given without a house (« Dons de la tournée »), or when the house took
  /// none ([calendarRefused]).
  final StreetChange? calendar;

  /// Why the house or door took no calendar (#155): no longer done (a
  /// teammate changed it meanwhile), too many calendars, the street gone.
  /// The money is still the tournée's. Null when it took one, or for a don
  /// without a house.
  final CommandFailure<CalendarChangeFailure>? calendarRefused;

  @override
  bool operator ==(Object other) =>
      other is AddedDonation &&
      other.round == round &&
      other.calendar == calendar &&
      other.calendarRefused == calendarRefused;

  @override
  int get hashCode => Object.hash(round, calendar, calendarRefused);

  @override
  String toString() => 'AddedDonation($round, ${calendar ?? calendarRefused})';
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
    return Ok(switch (calendar) {
      Ok(:final value) => AddedDonation(round: changed, calendar: value),
      Err(:final failure) => AddedDonation(
        round: changed,
        calendarRefused: failure,
      ),
    });
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

/// « Valider la tournée »: the tournée on becomes one « validated, not
/// yet sent » ([UnsentRound], PLAN §5.16), kept on the phone with its
/// summary until the server has it ([SendUnsentRounds] sends it), and the
/// phone forgets its dons. A validated tournée is never changed. Needs no
/// network. Returns it.
///
/// One write moves it (`OpenRoundStore.keepValidated`): killed at any
/// moment, the phone has it either on or validated, never both nor none.
final class ValidateRound {
  const ValidateRound(this._rounds, this._clock);

  final OpenRoundStore _rounds;
  final Clock _clock;

  Future<Result<UnsentRound, NoRoundOn>> call() async {
    final round = _rounds.openRound;
    if (round == null) return const Err(NoRoundOn());
    final validated = round.validate(_clock.now());
    await _rounds.keepValidated(validated);
    return Ok(validated);
  }
}

/// Sends to their secteur the validated tournées waiting on the phone
/// (PLAN §5.16, #143): those waiting now, then each that starts waiting
/// (« Valider la tournée », « Réessayer »). A summary the server keeps is
/// forgotten by the phone; one it refuses stays, marked refused, until
/// « Réessayer » or « Effacer ».
///
/// Runs while the app does (the composition root starts it). Offline, a
/// send simply waits for the server (`RoundLedger.record`). After a kill,
/// the next start sends again what was waiting, which the ledger keeps
/// once.
final class SendUnsentRounds {
  SendUnsentRounds(this._rounds, this._ledger);

  final OpenRoundStore _rounds;
  final RoundLedger _ledger;

  /// The tournées being sent now, not sent again meanwhile: two sends of
  /// one summary at once could reach the server as a create and then an
  /// update, which its rules refuse.
  final _sending = <RoundId>{};

  /// Starts sending; cancel the subscription to stop following new ones
  /// (a send under way still ends).
  StreamSubscription<List<UnsentRound>> call() {
    _sendWaiting(_rounds.unsent);
    return _rounds.unsentChanges.listen(_sendWaiting);
  }

  void _sendWaiting(List<UnsentRound> unsent) {
    for (final round in unsent) {
      if (round.state == UnsentState.waiting && _sending.add(round.id)) {
        unawaited(_send(round));
      }
    }
  }

  Future<void> _send(UnsentRound round) async {
    try {
      switch (await _ledger.record(
        round.sector,
        round.campaign,
        round.summary,
      )) {
        case LedgerAnswer.kept:
          await _rounds.forgetUnsent(round.id);
        case LedgerAnswer.refused:
          // Nothing happens when « Effacer » forgot it meanwhile.
          await _rounds.updateUnsent(round.refused());
      }
    } finally {
      _sending.remove(round.id);
    }
  }
}

/// « Réessayer » of a tournée the server refused (PLAN §5.16): it waits to
/// be sent again, which [SendUnsentRounds] does. Nothing happens for a
/// tournée not refused (waiting already, or gone).
final class RetryUnsentRound {
  const RetryUnsentRound(this._rounds);

  final OpenRoundStore _rounds;

  Future<void> call(RoundId id) async {
    final round = _refused(_rounds, id);
    if (round != null) await _rounds.updateUnsent(round.retried());
  }
}

/// « Effacer » of a tournée the server refused, once confirmed (PLAN
/// §5.16): the phone forgets it, its figures with it; the secteur never
/// counts it. Only a refused one: one still waiting may be on its way to
/// the server.
final class EraseUnsentRound {
  const EraseUnsentRound(this._rounds);

  final OpenRoundStore _rounds;

  Future<void> call(RoundId id) async {
    if (_refused(_rounds, id) != null) await _rounds.forgetUnsent(id);
  }
}

/// The tournée [id] of [rounds] the server refused; null for none.
UnsentRound? _refused(OpenRoundStore rounds, RoundId id) {
  for (final round in rounds.unsent) {
    if (round.id == id && round.state == UnsentState.refused) return round;
  }
  return null;
}

/// Whether the phone's tournées could not be read at start-up (#143): the
/// app started with none, and says so once on Accueil.
final class RoundsUnreadableAtStart {
  const RoundsUnreadableAtStart(this._rounds);

  final OpenRoundStore _rounds;

  bool call() => _rounds.unreadableAtStart;
}

/// « Abandonner » of « Abandonner la tournée ? » (#136), for a tournée
/// started by mistake: the phone forgets it and its dons, and nothing is
/// sent to the secteur, so « Collecte » never counts it. The houses marked
/// during it stay marked: they are the streets', not the tournée's. Needs
/// no network. Returns the tournée forgotten.
final class AbandonRound {
  const AbandonRound(this._rounds);

  final OpenRoundStore _rounds;

  Future<Result<Round, NoRoundOn>> call() async {
    final round = _rounds.openRound;
    if (round == null) return const Err(NoRoundOn());
    await _rounds.clear();
    return Ok(round);
  }
}

/// « Collecte 2026 » (PLAN §5.13, §5.16): the validated tournées of
/// [campaign] of [sector] and their totals, with apart those this phone
/// validated that the server does not have yet, now and again at each
/// change: a tournée validated by this phone or a teammate's, one sent,
/// refused or erased. Read from the phone's copy first, so it works
/// offline. Never split per member: a summary names none.
final class WatchCollecte {
  const WatchCollecte(this._ledger, this._rounds);

  final RoundLedger _ledger;
  final OpenRoundStore _rounds;

  Stream<Collecte> call(SectorId sector, CampaignYear campaign) {
    List<UnsentRound> ours(List<UnsentRound> unsent) => [
      for (final round in unsent)
        if (round.sector == sector && round.campaign == campaign) round,
    ];
    // Both sources in one stream, as soon as the ledger has answered once:
    // a controller, which starts listening to them when the screen does
    // and stops with it.
    List<RoundSummary>? summaries;
    var unsent = ours(_rounds.unsent);
    final subscriptions = <StreamSubscription<Object?>>[];
    late final StreamController<Collecte> out;
    void emit() {
      final known = summaries;
      if (known != null) out.add(Collecte.of(known, unsent: unsent));
    }

    out = StreamController(
      onListen: () {
        subscriptions
          ..add(
            _ledger.watch(sector, campaign).listen((read) {
              summaries = read;
              emit();
            }, onError: out.addError),
          )
          ..add(
            _rounds.unsentChanges.listen((changed) {
              unsent = ours(changed);
              emit();
            }),
          );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await out.close();
      },
    );
    return out.stream;
  }
}
