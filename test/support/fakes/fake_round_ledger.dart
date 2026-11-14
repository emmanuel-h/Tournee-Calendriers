// An in-memory RoundLedger that records what it is given, in order.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

final class FakeRoundLedger implements RoundLedger {
  /// Every summary recorded, with its secteur and campaign.
  final recorded = <(SectorId, CampaignYear, RoundSummary)>[];

  /// Every summary handed to [record], kept or not, in order.
  final asked = <RoundSummary>[];

  /// What [record] answers; [LedgerAnswer.kept] by default. A refused
  /// summary is not [recorded].
  var answer = LedgerAnswer.kept;

  /// When set, [record] waits for it before answering: the server not
  /// heard yet (offline).
  Completer<void>? server;

  /// Called inside [record], before it ends: lets a test look at the
  /// phone at that moment.
  void Function()? onRecord;

  final _changes = StreamController<void>.broadcast(sync: true);

  /// Every correction written, with the tournée it went to, in order.
  final corrected = <(SectorId, CampaignYear, RoundId, RoundCorrected)>[];

  /// Every forgotten house settled, with its tournée, in order.
  final settled = <(SectorId, CampaignYear, RoundId, ForgottenHouse)>[];

  /// Puts [summary] among those of [sector] and [campaign], as a teammate's
  /// phone would have, and tells the listeners.
  void have(SectorId sector, CampaignYear campaign, RoundSummary summary) {
    recorded.add((sector, campaign, summary));
    _changes.add(null);
  }

  @override
  Future<RoundSummary?> find(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
  ) async {
    for (final (s, c, summary) in recorded) {
      if (s == sector && c == campaign && summary.id == round) return summary;
    }
    return null;
  }

  @override
  Future<void> correct(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    RoundCorrected correction,
  ) async {
    corrected.add((sector, campaign, round, correction));
    _replace(
      sector,
      campaign,
      round,
      (old) => RoundSummary(
        id: old.id,
        startedAt: old.startedAt,
        endedAt: old.endedAt,
        housesVisited: old.housesVisited,
        totals: correction.totals,
        donations: correction.donations ?? old.donations,
        correctedAt: correction.correctedAt,
        housesToMark: old.housesToMark + correction.housesAdded,
      ),
    );
  }

  @override
  Future<void> settleForgottenHouse(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    ForgottenHouse settled,
  ) async {
    this.settled.add((sector, campaign, round, settled));
    _replace(
      sector,
      campaign,
      round,
      (old) => RoundSummary(
        id: old.id,
        startedAt: old.startedAt,
        endedAt: old.endedAt,
        housesVisited: switch (settled) {
          ForgottenHouse.marked => old.housesVisited + 1,
          ForgottenHouse.ignored => old.housesVisited,
        },
        totals: old.totals,
        donations: old.donations,
        correctedAt: old.correctedAt,
        housesToMark: old.housesToMark - 1,
      ),
    );
  }

  /// The summary [round] made anew by [change], as the server would.
  void _replace(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    RoundSummary Function(RoundSummary old) change,
  ) {
    for (final (index, (s, c, summary)) in recorded.indexed) {
      if (s == sector && c == campaign && summary.id == round) {
        recorded[index] = (s, c, change(summary));
        _changes.add(null);
        return;
      }
    }
  }

  @override
  Future<LedgerAnswer> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async {
    asked.add(summary);
    onRecord?.call();
    await server?.future;
    final answer = this.answer;
    if (answer == LedgerAnswer.kept) {
      recorded.add((sector, campaign, summary));
      _changes.add(null);
    }
    return answer;
  }

  /// The summaries recorded for [sector] and [campaign], now and after
  /// each [record].
  ///
  /// A controller rather than an `async*` generator: cancelling a
  /// generator waiting in an `await for` on [_changes] never completes.
  @override
  Stream<List<RoundSummary>> watch(SectorId sector, CampaignYear campaign) {
    List<RoundSummary> current() => [
      for (final (s, c, summary) in recorded)
        if (s == sector && c == campaign) summary,
    ];
    StreamSubscription<void>? changes;
    late final StreamController<List<RoundSummary>> out;
    out = StreamController(
      onListen: () {
        out.add(current());
        changes = _changes.stream.listen((_) => out.add(current()));
      },
      onCancel: () async {
        await changes?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }
}
