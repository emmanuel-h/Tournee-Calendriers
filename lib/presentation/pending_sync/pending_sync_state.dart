/// What the line « ☁ Modifications de 3 rues en attente d'envoi » of the
/// start screen shows (PLAN §5.3, §7). `sealed`: the screen's `switch`
/// handles each case.
sealed class PendingSyncState {
  const PendingSyncState();
}

/// No line: the server has everything this phone changed, or the count is
/// not known yet, or no tournée is open (the phone's own streets are never
/// sent).
final class AllSent extends PendingSyncState {
  const AllSent();

  @override
  bool operator ==(Object other) => other is AllSent;

  @override
  int get hashCode => (AllSent).hashCode;
}

/// Changes made on this phone wait to be sent in [streets] streets (at
/// least one): the count is of streets, not of changes, since Firestore
/// tells only whether a street has writes waiting.
final class ChangesWaiting extends PendingSyncState {
  const ChangesWaiting(this.streets);

  final int streets;

  @override
  bool operator ==(Object other) =>
      other is ChangesWaiting && other.streets == streets;

  @override
  int get hashCode => streets.hashCode;
}
