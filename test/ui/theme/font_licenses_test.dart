import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/theme/font_licenses.dart';

void main() {
  // Loading an asset needs the Flutter binding, even outside a widget test.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should list both bundled fonts with their OFL text when licences are registered', () async {
    registerFontLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    String textOf(String family) => entries
        .firstWhere((entry) => entry.packages.contains(family))
        .paragraphs
        .map((paragraph) => paragraph.text)
        .join('\n');

    expect(
      textOf('Atkinson Hyperlegible'),
      allOf(
        contains('Braille Institute of America'),
        contains('SIL Open Font License, Version 1.1'),
      ),
    );
    expect(
      textOf('Barlow Condensed'),
      allOf(
        contains('The Barlow Project Authors'),
        contains('SIL Open Font License, Version 1.1'),
      ),
    );
  });
}
