import 'dart:async';

import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

/// Where the app opens (PLAN §4, §5.1, §5.2). `sealed`: whoever shows it
/// must handle each case.
sealed class StartPoint {
  const StartPoint();
}

/// The start screen: the open tournée's streets, or the phone's own.
final class StartOnStreets extends StartPoint {
  const StartOnStreets();
}

/// « Bienvenue »: a phone the app knows nothing of yet.
final class StartOnWelcome extends StartPoint {
  const StartOnWelcome();
}

/// « Demande envoyée »: the member's [request] to join a tournée still
/// waits, and nothing else is on the phone.
final class StartOnRequest extends StartPoint {
  const StartOnRequest(this.request);

  final TourneeSummary request;

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
/// 1. a tournée is open → its streets (the last tournée, PLAN §4);
/// 2. the phone holds streets of its own (Corbeille included) → them, as
///    before any tournée existed (M1): nothing on the marking path waits
///    for a request;
/// 3. a request to join waits → its waiting screen, the latest one
///    (« Until accepted, the app shows this screen at every launch »);
/// 4. the phone knows tournées, none open → the start screen, whose title
///    opens « Mes tournées »;
/// 5. otherwise → « Bienvenue ».
///
/// Also where to go once a request is refused or cancelled.
final class ChooseStartPoint {
  const ChooseStartPoint(this._myTournees, this._phoneStreets);

  final MyTourneesStore _myTournees;

  /// The streets kept on the phone since M1, whichever tournée is open.
  final StreetRepository _phoneStreets;

  Future<StartPoint> call() async {
    final mine = _myTournees.myTournees;
    if (mine.currentId != null) return const StartOnStreets();
    if (await _holdsStreets()) return const StartOnStreets();
    final requests = mine.tournees.where((tournee) => tournee.isPending);
    if (requests.isNotEmpty) return StartOnRequest(requests.last);
    if (mine.tournees.isNotEmpty) return const StartOnStreets();
    return const StartOnWelcome();
  }

  /// Whether the phone keeps any street, in the Corbeille too: a street
  /// there can still be restored from « Importer des rues ». Each stream
  /// gives the streets now first.
  Future<bool> _holdsStreets() async =>
      (await _now(_phoneStreets.watchAll())).isNotEmpty ||
      (await _now(_phoneStreets.watchDeleted())).isNotEmpty;
}

/// The first value of [stream], then it stops listening.
///
/// Not `Stream.first`, which answers only once the stream has been let go:
/// an adapter may free it later, and the app's first screen must not wait
/// for that.
Future<T> _now<T>(Stream<T> stream) {
  final now = Completer<T>();
  late final StreamSubscription<T> listening;
  listening = stream.listen(
    (value) {
      now.complete(value);
      unawaited(listening.cancel());
    },
    onError: now.completeError,
    // An error ends it as well: nothing more comes.
    cancelOnError: true,
  );
  return now.future;
}
