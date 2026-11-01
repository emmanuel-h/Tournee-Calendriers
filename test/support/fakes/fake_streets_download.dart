// A hand-written StreetsDownload: answers what the test gives and records
// each call, so a use-case test needs no server.
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

final class FakeStreetsDownload implements StreetsDownload {
  FakeStreetsDownload([this.answer = const Ok([])]);

  /// The answer to every call.
  Result<List<Street>, StreetsDownloadFailure> answer;

  /// Every call, in order.
  final asked = <(TourneeId, CampaignYear)>[];

  @override
  Future<Result<List<Street>, StreetsDownloadFailure>> fromServer(
    TourneeId tournee,
    CampaignYear campaign,
  ) async {
    asked.add((tournee, campaign));
    return answer;
  }
}
