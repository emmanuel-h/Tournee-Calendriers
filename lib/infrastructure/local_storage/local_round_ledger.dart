import 'dart:convert';
import 'dart:io';

import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/atomic_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/round_summary_json_mapper.dart';

/// The [RoundLedger] of the phone alone: one JSON file per validated
/// tournée, `<sector>/<year>/<roundId>.json` in [directory] (PLAN §6.3,
/// `validated_rounds/`). No network, ever.
///
/// It stands in until the secteur's ledger on Firestore (#110): a tournée
/// validated meanwhile is kept, not lost, and can be sent then. One file
/// per tournée, written once: a validated tournée is never changed, so
/// nothing is ever read back and written again.
final class LocalRoundLedger implements RoundLedger {
  LocalRoundLedger(this.directory);

  /// The folder of the files; made at the first [record].
  final Directory directory;

  /// Writes the summary, unless that tournée is already kept: the first
  /// one stays, as the server's create-only rule keeps it (PLAN §8.2).
  @override
  Future<void> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async {
    final file = File(
      [
        directory.path,
        // Percent-encoded: whatever the ids hold, each stays one name.
        Uri.encodeComponent(sector.value),
        '${campaign.value}',
        '${Uri.encodeComponent(summary.id.value)}.json',
      ].join(Platform.pathSeparator),
    );
    // A sync check: `File.exists` would cost a round trip to another
    // thread (the `avoid_slow_async_io` lint).
    if (file.existsSync()) return;
    await file.parent.create(recursive: true);
    await writeAtomically(file, jsonEncode(roundSummaryToJson(summary)));
  }
}
