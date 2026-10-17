// Reads the Overpass responses captured in test/fixtures/overpass/ (see its
// README).
import 'dart:convert';
import 'dart:io';

/// The raw text of the fixture [name], as the service sent it.
String overpassFixtureText(String name) =>
    File('test/fixtures/overpass/$name').readAsStringSync();

/// The fixture [name] decoded the way `jsonDecode` hands it to the mapper.
Object? overpassFixture(String name) => jsonDecode(overpassFixtureText(name));
