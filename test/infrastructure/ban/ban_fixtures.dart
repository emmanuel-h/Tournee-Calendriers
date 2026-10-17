// Reads the BAN responses captured in test/fixtures/ban/ and the geocoding
// ones in test/fixtures/geopf/ (see their READMEs).
//
// `flutter test` runs with the project root as the working directory, so the
// relative path works from every test file.
import 'dart:convert';
import 'dart:io';

/// The raw text of the fixture [name], as the service sent it.
String banFixtureText(String name) =>
    File('test/fixtures/ban/$name').readAsStringSync();

/// The fixture [name] decoded the way `jsonDecode` hands it to the mappers.
Object? banFixture(String name) => jsonDecode(banFixtureText(name));

/// The raw text of the geocoding fixture [name] (test/fixtures/geopf/).
String geopfFixtureText(String name) =>
    File('test/fixtures/geopf/$name').readAsStringSync();

/// The geocoding fixture [name], decoded like [banFixture].
Object? geopfFixture(String name) => jsonDecode(geopfFixtureText(name));
