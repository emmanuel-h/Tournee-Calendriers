import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// Reads every street of a tournée from the server, so the phone keeps all
/// of them for a day offline (PLAN §7): Firestore's cache, with no size
/// limit, then answers every read without the network.
///
/// An outbound port: an adapter in `infrastructure/firestore/` implements
/// it, tests use a fake. Needs the network; a failure comes back as an
/// [Err], never as an exception.
abstract interface class StreetsDownload {
  /// Every street of [campaign] of [tournee], as the server has them now,
  /// those in the Corbeille included.
  Future<Result<List<Street>, StreetsDownloadFailure>> fromServer(
    TourneeId tournee,
    CampaignYear campaign,
  );
}

/// Why the streets could not be read from the server.
enum StreetsDownloadFailure {
  /// The phone could not reach the server, or it did not answer in time.
  noNetwork,

  /// The server refused or failed (the member was removed meanwhile, the
  /// service is down).
  serviceError,
}
