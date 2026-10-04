import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled fonts and their licence files (SIL Open Font License 1.1).
const _fontLicenses = {
  'Atkinson Hyperlegible': 'assets/fonts/atkinson_hyperlegible/OFL.txt',
  'Barlow Condensed': 'assets/fonts/barlow_condensed/OFL.txt',
};

/// Adds the bundled fonts' licences to the licences page (`showLicensePage`).
///
/// The OFL requires its notice to travel with the fonts. Packages from pub.dev
/// are registered by Flutter automatically; assets we ship ourselves are not.
/// The collector is an `async*` generator: Flutter only runs it, and reads the
/// files, when someone opens the licences page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: path) in _fontLicenses.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(path));
    }
  });
}
