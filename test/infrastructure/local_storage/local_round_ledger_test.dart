import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_round_ledger.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/round_summary_json_mapper.dart';

import '../../domain/round/round_fixtures.dart';

void main() {
  late Directory folder;
  late LocalRoundLedger ledger;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('round_ledger_test');
    // A folder not made yet, as before the first tournée.
    ledger = LocalRoundLedger(Directory('${folder.path}/validated_rounds'));
  });

  tearDown(() => folder.delete(recursive: true));

  final summary = newRound().visited().add(cash(1000)).validate(endedAt);

  Object? storedAt(String path) => jsonDecode(
    File('${folder.path}/validated_rounds/$path').readAsStringSync(),
  );

  test('should keep each tournée in a file of its secteur and year', () async {
    await ledger.record(sector49Id, year2026, summary);

    expect(storedAt('t49/2026/round-1.json'), roundSummaryToJson(summary));
  });

  test('should keep the first summary of a tournée recorded twice', () async {
    await ledger.record(sector49Id, year2026, summary);

    await ledger.record(
      sector49Id,
      year2026,
      newRound().validate(endedAt.add(const Duration(hours: 1))),
    );

    expect(storedAt('t49/2026/round-1.json'), roundSummaryToJson(summary));
  });

  test('should keep one name per id, whatever it holds', () async {
    final odd = RoundSummary(
      id: RoundId('a/b'),
      startedAt: summary.startedAt,
      endedAt: summary.endedAt,
      housesVisited: summary.housesVisited,
      totals: summary.totals,
    );

    await ledger.record(SectorId('t/49'), year2026, odd);

    expect(storedAt('t%2F49/2026/a%2Fb.json'), roundSummaryToJson(odd));
  });
}
