import 'package:tournee_calendriers/domain/street/visit_status.dart';

/// The steps of the status picker of a house or a door (PLAN §5.6): the
/// statuses first, then, only for the statuses that need more, a step of
/// their own in the same sheet.
enum PickerStep {
  /// « N° 7  À faire »: the statuses, one tap stores one.
  statuses,

  /// « N° 5 · quand repasser ? »: the day and the hour of a « repasser »
  /// (#81), each stored at once; « Valider » closes.
  comeBackTime,
}

/// The step that follows a tap on [status] in [PickerStep.statuses]; null
/// when the picker closes at once.
///
/// « Repasser » asks when, even on a house that already had it (nothing is
/// stored then, but its day can still be changed). The other statuses ask
/// for nothing more.
PickerStep? stepAfter(VisitStatus status) => switch (status) {
  VisitStatus.comeBack => PickerStep.comeBackTime,
  VisitStatus.toDo ||
  VisitStatus.done ||
  VisitStatus.refused ||
  VisitStatus.nobodyHome => null,
};
