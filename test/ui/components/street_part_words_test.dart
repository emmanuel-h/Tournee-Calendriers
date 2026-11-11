import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/ui/components/street_part_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

import '../../support/street_fixtures.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  for (final (held, text) in [
    (StreetPart.whole, 'Toute la rue'),
    (part(odd: SidePart.none, even: SidePart.none), 'Aucun numéro'),
    (part(odd: range(7, 21), even: range(2, 30)), 'Impairs 7–21 · pairs 2–30'),
    (part(odd: SidePart.none, even: range(2, 8)), 'Pairs 2–8'),
    (part(odd: range(1, 57), even: SidePart.none), 'Impairs 1–57'),
    (part(odd: SidePart.all, even: SidePart.none), 'Tous les impairs'),
    (part(odd: SidePart.none, even: SidePart.all), 'Tous les pairs'),
    (
      part(odd: SidePart.all, even: range(2, 30)),
      'Tous les impairs · pairs 2–30',
    ),
    (
      part(odd: range(7, 21), even: SidePart.all),
      'Impairs 7–21 · tous les pairs',
    ),
    (part(odd: range(7, 7), even: SidePart.none), 'Impair 7'),
    (part(odd: range(7, 21), even: range(8, 8)), 'Impairs 7–21 · pair 8'),
    (part(odd: SidePart.none, even: range(0, 10000)), 'Pairs 0–10000'),
  ]) {
    test('should say « $text »', () {
      expect(streetPartText(l10n, held), text);
    });
  }

  for (final (place, text) in [
    (const MarkBefore(1), 'avant le 1'),
    (const MarkBetween(5, 7), 'entre 5 et 7'),
    (const MarkAfter(41), 'après le 41'),
  ]) {
    test('should place a mark « $text »', () {
      expect(markPlaceText(l10n, place), text);
    });
  }
}
