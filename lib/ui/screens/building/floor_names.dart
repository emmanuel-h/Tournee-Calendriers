import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// « RdC », « 1er », « 2e »…, or « Logements » for the single row of a
/// building whose floors are unknown ([level] null).
String floorName(AppLocalizations l10n, int? level) => switch (level) {
  null => l10n.floorUnknown,
  0 => l10n.floorGround,
  1 => l10n.floorFirst,
  final level => l10n.floorNth(level),
};

/// What screen readers hear for a door: « Escalier A, 5e, porte 51, fait ».
/// The staircase is named only when the building has several
/// ([namesStaircase]), and « Logements » is left out: every door of such a
/// building is on that row.
String doorSpoken(
  AppLocalizations l10n,
  DwellingKey key, {
  required bool namesStaircase,
  required String status,
}) => [
  if (namesStaircase) l10n.staircaseSpoken(key.staircase.letter),
  if (key.level != null) floorName(l10n, key.level),
  l10n.doorSpoken(key.label.text),
  status,
].join(', ');
