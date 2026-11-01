/// Whether this phone reaches the server now: what « Mes tournées » needs
/// to grey, offline, a tournée never downloaded here (« Disponible avec
/// réseau », PLAN §5.3).
///
/// An application port: the use cases own it, the Firestore street adapter
/// of the open tournée implements it from the metadata of its snapshots
/// (`isFromCache`), so no connectivity plugin is needed. That listener
/// already runs for the marking path; it says « from the phone's copy »
/// as soon as Firestore stops reaching the server, and « from the server »
/// once it reaches it again.
abstract interface class ServerConnection {
  /// True while what the phone shows comes from its own copy only (no
  /// network, or the server out of reach), false once the server answers;
  /// now and after each change. Nothing is given before the first answer.
  Stream<bool> watchOffline();
}
