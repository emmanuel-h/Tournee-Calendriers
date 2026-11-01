import 'package:tournee_calendriers/application/ports/server_connection.dart';

/// Whether the phone is offline (cannot reach the server), now and after
/// each change: « Mes tournées » greys, offline, the tournées it could not
/// open (PLAN §5.3).
final class ObserveOffline {
  const ObserveOffline(this._connection);

  final ServerConnection _connection;

  /// True while offline, false once the server answers.
  Stream<bool> call() => _connection.watchOffline();
}
