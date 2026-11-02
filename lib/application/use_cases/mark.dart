import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// One mark set from the status picker of a house or a door (PLAN §5.6):
/// its status, the time of its « repasser », or « De nouveau personne ».
/// The picker stores each choice at once, so each one is a change of its
/// own, undone on its own.
///
/// `sealed`: these are the only marks, so a `switch` over a `Mark` handles
/// each one.
sealed class Mark {
  const Mark();
}

/// A status of the picker (« ✓ Fait », « ✗ Personne »…).
final class StatusMark extends Mark {
  const StatusMark(this.status);

  final VisitStatus status;
}

/// The time of a house or door « repasser » (« Quand repasser ? »), or the
/// « Repasser » box of a building itself and its time (null when the box is
/// unticked).
final class ComeBackMark extends Mark {
  const ComeBackMark(this.comeBack);

  final ComeBack? comeBack;
}

/// « De nouveau personne » (#80): nobody home once more, one more
/// try counted.
final class NobodyHomeAgainMark extends Mark {
  const NobodyHomeAgainMark();
}
