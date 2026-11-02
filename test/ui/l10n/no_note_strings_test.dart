import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Free-text notes were removed for privacy (PLAN §8.3, Q23): nothing the
/// app shows may still offer, name or describe one.
void main() {
  test('should have no message about a note in the French messages', () {
    // The test runs from the project's root, where the ARB file is.
    final arb = jsonDecode(
      File('lib/ui/l10n/app_fr.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    // « note », « notes », « Note » as a word; not « annoter », « notice »
    // or « noté » (written down). `\p{L}` is any letter, accents included,
    // which `\b` does not know.
    final note = RegExp(
      r'(?<!\p{L})notes?(?!\p{L})',
      caseSensitive: false,
      unicode: true,
    );
    // The privacy page says there is none (« pas de note », PRIVACY.md,
    // #79): that names no note to write.
    String said(String value) => value.replaceAll('pas de note', '');

    final offenders = [
      for (final MapEntry(:key, :value) in arb.entries)
        if (!key.startsWith('@') &&
            (key.toLowerCase().contains('note') ||
                note.hasMatch(said('$value'))))
          key,
    ];

    expect(offenders, isEmpty);
    // Not vacuous: the file was read and holds the messages.
    expect(arb, contains('buildingDetails'));
    expect(arb['privacyDataBody'], contains('pas de note'));
  });
}
