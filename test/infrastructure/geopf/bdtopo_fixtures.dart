// Reads the IGN BD TOPO answers captured in test/fixtures/bdtopo/ (see its
// README).
//
// `flutter test` runs with the project root as the working directory, so the
// relative path works from every test file.
import 'dart:convert';
import 'dart:io';

/// The raw text of the BD TOPO fixture [name], as the service sent it.
String bdTopoFixtureText(String name) =>
    File('test/fixtures/bdtopo/$name').readAsStringSync();

/// The fixture [name] decoded the way `jsonDecode` hands it to the mapper.
Object? bdTopoFixture(String name) => jsonDecode(bdTopoFixtureText(name));
