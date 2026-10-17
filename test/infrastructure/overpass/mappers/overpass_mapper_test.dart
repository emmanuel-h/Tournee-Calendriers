import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/overpass/mappers/overpass_mapper.dart';

import '../../../support/geo_fixtures.dart';
import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';
import '../overpass_fixtures.dart';

void main() {
  StreetName name(String text) => valueOf(StreetName.create(text));

  const a = '(a|à|â|ä|A|À|Â|Ä)';
  const c = '(c|ç|C|Ç)';
  const e = '(e|é|è|ê|ë|E|É|È|Ê|Ë)';
  const i = '(i|î|ï|I|Î|Ï)';
  const o = '(o|ô|ö|O|Ô|Ö)';
  const u = '(u|ù|û|ü|U|Ù|Û|Ü)';
  const y = '(y|ÿ|Y|Ÿ)';
  const gap = '(-| )';
  const apostrophe = "('|’)";

  group('streetNamePattern', () {
    test('should match the whole name, ignoring the case of the vowels', () {
      expect(streetNamePattern(name('Rue Lulli')), '^R$u$e${gap}L${u}ll$i\$');
    });

    test('should take an accented letter for its plain letter', () {
      expect(streetNamePattern(name('Église')), '^${e}gl${i}s$e\$');
      expect(streetNamePattern(name('ÂÀÄ')), '^$a$a$a\$');
      expect(streetNamePattern(name('Ôö')), '^$o$o\$');
      expect(streetNamePattern(name('Ùûü')), '^$u$u$u\$');
      expect(streetNamePattern(name('Îï')), '^$i$i\$');
      expect(streetNamePattern(name('Ÿÿ')), '^$y$y\$');
    });

    test('should take a cedilla for its plain letter', () {
      expect(streetNamePattern(name('Ça')), '^$c$a\$');
    });

    test('should take either apostrophe for the other', () {
      expect(streetNamePattern(name("d'x")), '^d${apostrophe}x\$');
      expect(streetNamePattern(name('d’x')), '^d${apostrophe}x\$');
    });

    test('should take a hyphen and a space for one another', () {
      expect(
        streetNamePattern(name('Saint-Lt 8')),
        '^S$a${i}nt${gap}Lt${gap}8\$',
      );
    });

    test('should escape the signs a regular expression gives a meaning', () {
      expect(
        streetNamePattern(name(r'.^$*+?()[]{}|\')),
        r'^\.\^\$\*\+\?\(\)\[\]\{\}\|\\$',
      );
    });

    test('should keep the other letters, signs and digits as they are', () {
      expect(streetNamePattern(name('BdœÑ/1')), r'^BdœÑ/1$');
    });
  });

  group('overpassStreetQuery', () {
    test('should ask for the named highways in the commune boundary', () {
      expect(
        overpassStreetQuery(name('Rue d’Alma'), insee('69264')),
        '[out:json][timeout:15];\n'
        'area["ref:INSEE"="69264"]["boundary"="administrative"]'
        '["admin_level"="8"]->.commune;\n'
        'way(area.commune)["highway"]'
        '["name"~"^R$u$e${gap}d$apostrophe${a}lm$a\$",i];\n'
        'out geom;',
      );
    });

    test('should escape backslashes and quotes inside the query string', () {
      expect(
        overpassStreetQuery(name(r'B"\'), insee('69264')),
        contains(r'["name"~"^B\"\\\\$",i]'),
      );
    });
  });

  group('streetShapeFromJson', () {
    // An Overpass answer holding [elements].
    Map<String, Object?> answer(List<Object?> elements) => {
      'version': 0.6,
      'elements': elements,
    };

    // A way going through [points], each a (latitude, longitude) pair.
    Map<String, Object?> way(List<Object?> points) => {
      'type': 'way',
      'id': 1,
      'geometry': points,
    };

    final aWay = way([
      {'lat': 45.9883637, 'lon': 4.7380971},
      {'lat': 45.9884665, 'lon': 4.7387106},
    ]);
    final aLine = [at(45.9883637, 4.7380971), at(45.9884665, 4.7387106)];

    test('should read one line per way, in the order the road runs', () {
      final shape = streetShapeFromJson(
        overpassFixture('rue_des_freres_bonnet.json'),
      );

      expect(shape.lines, hasLength(3));
      expect(shape.lines.first, [
        at(45.9885563, 4.7392065),
        at(45.9887501, 4.7403707),
        at(45.9889835, 4.7417936),
        at(45.9890773, 4.7423746),
        at(45.9891443, 4.7428004),
      ]);
      expect(shape.lines[1], hasLength(4));
      expect(shape.lines.last, [
        at(45.9891443, 4.7428004),
        at(45.9891268, 4.7428987),
        at(45.9891127, 4.7429775),
      ]);
    });

    test('should read the answer of another server alike', () {
      final shape = streetShapeFromJson(
        overpassFixture('rue_pierre_morin.json'),
      );

      expect(shape.lines.map((line) => line.length), [3, 5, 3]);
    });

    test('should give no shape when no road has the name', () {
      expect(
        streetShapeFromJson(overpassFixture('no_way.json')),
        StreetShape.none,
      );
    });

    test('should read whole-number coordinates', () {
      final shape = streetShapeFromJson(
        answer([
          way([
            {'lat': 46, 'lon': 4},
            {'lat': 45, 'lon': 5},
          ]),
        ]),
      );

      expect(shape.lines.single, [at(46, 4), at(45, 5)]);
    });

    group('should leave out an element', () {
      final unreadable = <String, Object?>{
        'that is not a map': 'way',
        'that is a node': {'type': 'node', 'lat': 45.98, 'lon': 4.72},
        'without a type': {'geometry': aWay['geometry']},
        'without a geometry': {'type': 'way', 'id': 1},
        'whose geometry is not a list': {'type': 'way', 'geometry': 'line'},
        'with a point that is not a map': way([
          'here',
          {'lat': 45.9884665, 'lon': 4.7387106},
        ]),
        'with a point without a latitude': way([
          {'lon': 4.7380971},
          {'lat': 45.9884665, 'lon': 4.7387106},
        ]),
        'with a point whose longitude is text': way([
          {'lat': 45.9883637, 'lon': '4.7380971'},
          {'lat': 45.9884665, 'lon': 4.7387106},
        ]),
        'with a point out of range': way([
          {'lat': 45.9883637, 'lon': 4.7380971},
          {'lat': 95.0, 'lon': 4.7387106},
        ]),
        'of a single point': way([
          {'lat': 45.9883637, 'lon': 4.7380971},
        ]),
      };

      unreadable.forEach((description, element) {
        test(description, () {
          expect(streetShapeFromJson(answer([element, aWay])).lines, [aLine]);
        });
      });
    });

    group('should throw a FormatException when the answer', () {
      final notShapes = <String, Object?>{
        'is not a map': [aWay],
        'has no elements': {'version': 0.6},
        'has elements that are not a list': {'elements': 'none'},
        'reports a runtime error': overpassFixture('runtime_error.json'),
        'has a remark beside its elements': {
          'elements': [aWay],
          'remark': 'runtime error: Query timed out in "query" at line 3',
        },
      };

      notShapes.forEach((description, json) {
        test(description, () {
          expect(() => streetShapeFromJson(json), throwsFormatException);
        });
      });
    });
  });
}
