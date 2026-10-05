import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// One mark set from the sheet of a house or a door (PLAN §5.7): its
/// status, its « repasser » or its note. The sheet stores each control as
/// soon as it changes, so each one is a change of its own, undone on its
/// own.
///
/// `sealed`: these three are the only marks, so a `switch` over a `Mark`
/// handles each one.
sealed class Mark {
  const Mark();
}

/// The status control (« À faire | Fait | Personne | Repasser »).
final class StatusMark extends Mark {
  const StatusMark(this.status);

  final VisitStatus status;
}

/// The hint of a house or door « repasser » (« Quand repasser ? »), or the
/// « Repasser » box of a building itself and its hint (null when the box is
/// unticked).
final class ComeBackMark extends Mark {
  const ComeBackMark(this.comeBack);

  final ComeBack? comeBack;
}

/// The note field; `Note.empty` once erased.
final class NoteMark extends Mark {
  const NoteMark(this.note);

  final Note note;
}
