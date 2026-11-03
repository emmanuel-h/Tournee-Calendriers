// An in-memory RoundLedger that records what it is given, in order.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

final class FakeRoundLedger implements RoundLedger {
  /// Every summary recorded, with its secteur and campaign.
  final recorded = <(SectorId, CampaignYear, RoundSummary)>[];

  /// Called inside [record], before it ends: lets a test look at the
  /// phone at that moment.
  void Function()? onRecord;

  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Future<void> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async {
    onRecord?.call();
    recorded.add((sector, campaign, summary));
    _changes.add(null);
  }

  /// The summaries recorded for [sector] and [campaign], now and after
  /// each [record].
  @override
  Stream<List<RoundSummary>> watch(
    SectorId sector,
    CampaignYear campaign,
  ) async* {
    List<RoundSummary> current() => [
      for (final (s, c, summary) in recorded)
        if (s == sector && c == campaign) summary,
    ];
    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }
}
