import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';

/// Where the app opens (PLAN §4, §5.1, §5.2). `sealed`: whoever shows it
/// must handle each case.
sealed class StartPoint {
  const StartPoint();
}

/// The start screen: Accueil of the open secteur, or « Aucun secteur
/// ouvert » when none is.
final class StartOnStreets extends StartPoint {
  const StartOnStreets();
}

/// « Bienvenue »: a phone the app knows nothing of yet.
final class StartOnWelcome extends StartPoint {
  const StartOnWelcome();
}

/// « Demande envoyée »: the member's [request] to join a secteur still
/// waits, and no secteur is open.
final class StartOnRequest extends StartPoint {
  const StartOnRequest(this.request);

  final SectorSummary request;

  @override
  bool operator ==(Object other) =>
      other is StartOnRequest && other.request == request;

  @override
  int get hashCode => request.hashCode;

  @override
  String toString() => 'StartOnRequest(${request.id.value})';
}

/// Chooses where the app opens, from what the phone holds alone: no
/// network, so an offline cold start opens where it should (PLAN §7).
///
/// In this order:
/// 1. a secteur is open → its Accueil (the last secteur, PLAN §4);
/// 2. a request to join waits → its waiting screen, the latest one
///    (« Until accepted, the app shows this screen at every launch »);
/// 3. the phone knows secteurs, none open → the start screen with none
///    open (« Aucun secteur ouvert », PLAN §5.0);
/// 4. otherwise → « Bienvenue ».
///
/// Also where to go once a request is refused or cancelled.
final class ChooseStartPoint {
  const ChooseStartPoint(this._mySectors);

  final MySectorsStore _mySectors;

  /// A `Future`, though the answer is at hand: the app waits for it as for
  /// any start-up read (`launchPlaceProvider`).
  Future<StartPoint> call() async {
    final mine = _mySectors.mySectors;
    if (mine.currentId != null) return const StartOnStreets();
    final requests = mine.sectors.where((sector) => sector.isPending);
    if (requests.isNotEmpty) return StartOnRequest(requests.last);
    if (mine.sectors.isNotEmpty) return const StartOnStreets();
    return const StartOnWelcome();
  }
}
