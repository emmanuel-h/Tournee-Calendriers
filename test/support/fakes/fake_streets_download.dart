// A hand-written StreetsDownload: answers what the test gives and records
// each call, so a use-case test needs no server.
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';

final class FakeStreetsDownload implements StreetsDownload {
  FakeStreetsDownload([this.answer = const Ok([])]);

  /// The answer to every call.
  Result<List<Street>, StreetsDownloadFailure> answer;

  /// Every call, in order.
  final asked = <(SectorId, CampaignYear)>[];

  @override
  Future<Result<List<Street>, StreetsDownloadFailure>> fromServer(
    SectorId sector,
    CampaignYear campaign,
  ) async {
    asked.add((sector, campaign));
    return answer;
  }
}
