// Reads the geo.api.gouv.fr responses captured in test/fixtures/geo_api/
// (see its README). `flutter test` runs from the project root.
import 'dart:convert';
import 'dart:io';

/// The raw text of the fixture [name], as the service sent it.
String geoApiFixtureText(String name) =>
    File('test/fixtures/geo_api/$name').readAsStringSync();

/// The fixture [name] decoded the way `jsonDecode` hands it to the mapper.
Object? geoApiFixture(String name) => jsonDecode(geoApiFixtureText(name));
