import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

// The French words of the part of a street a secteur holds (PLAN §5.15),
// shared by « Partie de la rue », the rows of « Ajouter des rues » and the
// edit mode.

/// [part] in words: « Toute la rue », « Aucun numéro », « Pairs 2–8 »,
/// « Impairs 7–21 · pairs 2–30 ». A side held whole beside a cut one is
/// « tous les impairs »; a side holding nothing is left unsaid. Without
/// [capitalised], it starts in lowercase, to follow « Secteur 12 : ».
String streetPartText(
  AppLocalizations l10n,
  StreetPart part, {
  bool capitalised = true,
}) {
  final text = _partWords(l10n, part);
  final first = capitalised ? text[0].toUpperCase() : text[0].toLowerCase();
  return '$first${text.substring(1)}';
}

String _partWords(AppLocalizations l10n, StreetPart part) {
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
  // The words of a side are in lowercase, as they read after « · »; the
  // caller chooses the first letter.
  return switch ((odd, even)) {
    (null, null) => l10n.streetPartNothing,
    (final odd?, null) => odd,
    (null, final even?) => even,
    (final odd?, final even?) => l10n.streetPartBothSides(odd, even),
  };
}

/// The line under a street to add that another secteur holds: « Secteur
/// 12 : impairs 19–41 », « Secteur 3 (CS Arnas) : toute la rue ».
String otherSectorText(AppLocalizations l10n, OtherSectorLine line) =>
    l10n.otherSectorPart(
      line.sector,
      _centreText(l10n, line.centre),
      streetPartText(l10n, line.part, capitalised: false),
    );

/// The amber warning of « Partie de la rue » for one other secteur: « Le 19
/// et le 21 sont aussi dans le secteur 12 (CS Villefranche). »; past five
/// numbers, only how many.
String overlapText(AppLocalizations l10n, OverlapLine line) {
  final centre = _centreText(l10n, line.centre);
  final numbers = line.numbers;
  if (numbers.length > 5) {
    return l10n.streetPartSharedMany(numbers.length, line.sector, centre);
  }
  if (numbers.length == 1) {
    return l10n.streetPartSharedOne(numbers.single, line.sector, centre);
  }
  final before = [
    l10n.streetPartSharedFirst(numbers.first),
    for (final number in numbers.sublist(1, numbers.length - 1))
      l10n.streetPartSharedNext(number),
  ].join();
  return l10n.streetPartSharedSome(before, numbers.last, line.sector, centre);
}

/// « (CS Arnas) » after a secteur's number, or nothing for this secteur's
/// own centre.
String _centreText(AppLocalizations l10n, String? centre) =>
    centre == null ? '' : l10n.streetPartSharedCentre(centre);

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
