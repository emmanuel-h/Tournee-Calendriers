/// What the card « 12 rues sont enregistrées sur ce téléphone. » of the
/// start screen shows (PLAN §5.0). `sealed`: the screen's `switch` handles
/// each case.
sealed class MoveStreetsState {
  const MoveStreetsState();
}

/// No card: no tournée is open, the phone holds no street, they already
/// went into this tournée, the member put it off (« Plus tard »), or the
/// phone's streets are still being counted.
final class NoStreetsToMove extends MoveStreetsState {
  const NoStreetsToMove();

  @override
  bool operator ==(Object other) => other is NoStreetsToMove;

  @override
  int get hashCode => (NoStreetsToMove).hashCode;
}

/// The card offers the [count] streets of the phone to the open tournée:
/// « Les ajouter à la tournée » or « Plus tard ».
final class StreetsToMove extends MoveStreetsState {
  const StreetsToMove(this.count);

  final int count;

  @override
  bool operator ==(Object other) =>
      other is StreetsToMove && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

/// The streets are going into the tournée: « Ajout en cours… 3/12 ».
final class MovingStreets extends MoveStreetsState {
  const MovingStreets({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is MovingStreets && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);
}

/// What the move did, for the message after it: « 12 rues ajoutées à la
/// tournée », « 10 rues ajoutées, 2 déjà dans la tournée ».
final class MovedSummary {
  const MovedSummary({required this.moved, required this.alreadyThere});

  /// The streets added to the tournée.
  final int moved;

  /// The streets left out because the tournée already had them.
  final int alreadyThere;

  @override
  bool operator ==(Object other) =>
      other is MovedSummary &&
      other.moved == moved &&
      other.alreadyThere == alreadyThere;

  @override
  int get hashCode => Object.hash(moved, alreadyThere);
}
