/// What this phone has changed that the server has not received yet
/// (« ☁ Modifications de 3 rues en attente d'envoi », PLAN §7): marks made
/// offline wait on the phone and leave with the network.
///
/// An application port: the use cases own it, the Firestore street adapter
/// implements it from the metadata of its snapshots (`hasPendingWrites`).
abstract interface class PendingSync {
  /// The number of streets holding changes made on this phone that the
  /// server has not received yet, now and after each change; 0 once all
  /// is sent.
  ///
  /// Streets, not changes: Firestore says of each document whether writes
  /// wait for it, not how many, and its queue outlives a restart while a
  /// count kept by the app would not. Three marks waiting in one street
  /// count once.
  Stream<int> watchUnsentStreets();
}
