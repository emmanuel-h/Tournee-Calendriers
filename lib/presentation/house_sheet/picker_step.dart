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

  /// « Montant du don », after a « Fait » stored while a tournée is on
  /// (PLAN §5.13), or « + Ajouter un don » on a house done: the method,
  /// 5 / 10 / 20 €, « Autre montant » or « Calendrier offert ».
  donation,

  /// « Autre montant », from [donation]: the amount typed in.
  otherAmount,
}

/// The step that follows a tap on [status] in [PickerStep.statuses]; null
/// when the picker closes at once. [roundOn]: a tournée is on in the
/// secteur shown; [stored]: the tap changed the house (it did not have
/// [status] already).
///
/// « Repasser » asks when, even on a house that already had it (nothing is
/// stored then, but its day can still be changed). « Fait » asks for the
/// don during a tournée, once it is stored: a house already done takes
/// another don through « + Ajouter un don » instead. The other statuses
/// ask for nothing more.
PickerStep? stepAfter(
  VisitStatus status, {
  required bool roundOn,
  required bool stored,
}) => switch (status) {
  VisitStatus.comeBack => PickerStep.comeBackTime,
  VisitStatus.done when roundOn && stored => PickerStep.donation,
  VisitStatus.toDo ||
  VisitStatus.done ||
  VisitStatus.refused ||
  VisitStatus.nobodyHome => null,
};
