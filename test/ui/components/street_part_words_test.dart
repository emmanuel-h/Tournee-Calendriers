import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';
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

  test('should start in lowercase when asked', () {
    expect(
      streetPartText(l10n, StreetPart.whole, capitalised: false),
      'toute la rue',
    );
    expect(
      streetPartText(
        l10n,
        part(odd: range(19, 41), even: SidePart.none),
        capitalised: false,
      ),
      'impairs 19–41',
    );
  });

  test(
    'should say which part another secteur holds, its centre when given',
    () {
      final odd = part(odd: range(19, 41), even: SidePart.none);

      expect(
        otherSectorText(l10n, OtherSectorLine(sector: 12, part: odd)),
        'Secteur 12\u00a0: impairs 19–41',
      );
      expect(
        otherSectorText(
          l10n,
          const OtherSectorLine(
            sector: 3,
            centre: 'CS Arnas',
            part: StreetPart.whole,
          ),
        ),
        'Secteur 3 (CS Arnas)\u00a0: toute la rue',
      );
    },
  );

  for (final (numbers, centre, text) in [
    (['19'], null, 'Le 19 est aussi dans le secteur 12.'),
    (
      ['19', '21'],
      'CS Villefranche',
      'Le 19 et le 21 sont aussi dans le secteur 12 (CS Villefranche).',
    ),
    (
      ['19', '21', '23bis'],
      null,
      'Le 19, le 21 et le 23bis sont aussi dans le secteur 12.',
    ),
    (
      ['1', '3', '5', '7', '9'],
      null,
      'Le 1, le 3, le 5, le 7 et le 9 sont aussi dans le secteur 12.',
    ),
    (
      ['1', '3', '5', '7', '9', '11'],
      'CS Arnas',
      '6 numéros sont aussi dans le secteur 12 (CS Arnas).',
    ),
  ]) {
    test('should warn « $text »', () {
      expect(
        overlapText(
          l10n,
          OverlapLine(sector: 12, centre: centre, numbers: numbers),
        ),
        text,
      );
    });
  }
}
