import 'package:tournee_calendriers/application/ports/pending_sync.dart';

/// « ☁ Modifications de 3 rues en attente d'envoi » (PLAN §5.3, §7): how
/// many streets hold changes made on this phone that the server has not
/// received yet, now and after each change. Works offline: that is when
/// the count grows.
final class ObservePendingSync {
  const ObservePendingSync(this._pending);

  final PendingSync _pending;

  /// The number of streets with unsent changes; 0 once all is sent.
  Stream<int> call() => _pending.watchUnsentStreets();
}
