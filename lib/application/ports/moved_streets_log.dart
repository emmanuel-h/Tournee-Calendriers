import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// Which tournées received the streets kept on this phone since M1
/// (« Les ajouter à la tournée », PLAN §5.0), so they are never offered
/// twice to the same tournée. Another tournée may still be offered them.
///
/// An application port: the use cases own it, an adapter of
/// `infrastructure/local_storage/` keeps it in a file of the phone, tests
/// use a fake. Read without waiting: the adapter loads it before the first
/// screen, as « Mes tournées ».
abstract interface class MovedStreetsLog {
  /// Whether the phone's streets already went into [tournee].
  bool wereMovedInto(TourneeId tournee);

  /// Keeps that the phone's streets went into [tournee]. [wereMovedInto]
  /// says so at once; the returned `Future` ends once it is on the phone.
  Future<void> rememberMovedInto(TourneeId tournee);
}
