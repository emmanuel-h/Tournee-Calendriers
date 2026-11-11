import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

// The French words of the part of a street a secteur holds (PLAN §5.15),
// shared by « Partie de la rue », the rows of « Ajouter des rues » and the
// edit mode.

/// [part] in words: « Toute la rue », « Aucun numéro », « Pairs 2–8 »,
/// « Impairs 7–21 · pairs 2–30 ». A side held whole beside a cut one is
/// « tous les impairs »; a side holding nothing is left unsaid.
String streetPartText(AppLocalizations l10n, StreetPart part) {
  if (part.isWhole) return l10n.streetPartWhole;
  final odd = _sideText(
    part.odd,
    all: l10n.streetPartOddAll,
    one: l10n.streetPartOddOne,
    range: l10n.streetPartOddRange,
  );
  final even = _sideText(
    part.even,
    all: l10n.streetPartEvenAll,
    one: l10n.streetPartEvenOne,
    range: l10n.streetPartEvenRange,
  );
  final text = switch ((odd, even)) {
    (null, null) => l10n.streetPartNothing,
    (final odd?, null) => odd,
    (null, final even?) => even,
    (final odd?, final even?) => l10n.streetPartBothSides(odd, even),
  };
  // The words of a side are in lowercase, as they read after « · »; the
  // text starts with a capital.
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

/// The words of one [side]; null when it holds nothing. [one] and [range]
/// are the side's messages, passed as functions (`l10n.streetPartOddRange`
/// is a method torn off its object).
String? _sideText(
  SidePart side, {
  required String all,
  required String Function(int number) one,
  required String Function(int from, int to) range,
}) => switch (side) {
  AllNumbers() => all,
  NoNumbers() => null,
  NumberRange(:final from, :final to) when from == to => one(from),
  NumberRange(:final from, :final to) => range(from, to),
};

/// Where a mark of « Partie de la rue » stands, in words: « entre 5 et 7 »,
/// « avant le 1 », « après le 41 ».
String markPlaceText(AppLocalizations l10n, MarkPlace place) => switch (place) {
  MarkBefore(:final number) => l10n.streetPartBefore(number),
  MarkBetween(:final before, :final after) => l10n.streetPartBetween(
    before,
    after,
  ),
  MarkAfter(:final number) => l10n.streetPartAfter(number),
};
