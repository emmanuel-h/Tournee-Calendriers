import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// French typography puts a space inside « » and before : ; ? !. A plain
/// space there lets a line wrap between the word and its sign, leaving a
/// lone « or ? at the start or end of a line; a non-breaking space
/// (U+00A0) keeps them together.
///
/// Returns each place in [message] where a plain space sits there,
/// as « what is around it ».
List<String> plainSpacesInFrench(String message) => [
  for (final match in RegExp('« | »| [:;?!]').allMatches(message))
    message.substring(
      (match.start - 6).clamp(0, message.length),
      (match.end + 6).clamp(0, message.length),
    ),
];

void main() {
  group('plainSpacesInFrench', () {
    test('should find a plain space after «, before » and before : ; ? !', () {
      for (final (message, around) in [
        ('« Gauche', '« Gauche'),
        ('Gauche »', 'Gauche »'),
        ('Note : x', 'Note : x'),
        ('un ; deux', 'un ; deux'),
        ('Supprimer ?', 'primer ?'),
        ('Fait !', 'Fait !'),
      ]) {
        expect(plainSpacesInFrench(message), [around], reason: message);
      }
    });

    test('should accept non-breaking spaces, the spaces outside « » and '
        'signs without a space', () {
      expect(
        plainSpacesInFrench('Touchez « Gauche », puis : 14:02 ?'),
        isEmpty,
      );
    });
  });

  test('should keep no plain space inside « » or before : ; ? ! in the '
      'French messages', () {
    // The test runs from the project's root, where the ARB file is.
    final arb = jsonDecode(
      File('lib/ui/l10n/app_fr.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    // Keys starting with « @ » describe a message for translators and are
    // never shown; only the messages themselves are checked.
    final offenders = {
      for (final MapEntry(:key, :value) in arb.entries)
        if (!key.startsWith('@') && value is String)
          if (plainSpacesInFrench(value) case final found when found.isNotEmpty)
            key: found,
    };
    expect(offenders, isEmpty);
  });
}
