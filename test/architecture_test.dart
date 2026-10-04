// Enforces the dependency rule of PLAN §10.1 on the real `lib/` folder, and
// proves on in-memory fixtures that the rule checker really catches each kind
// of violation (so a green run on `lib/` means something).
//
// It runs on the plain Dart VM (`package:test`), no Flutter engine needed,
// which keeps it well under a second.
import 'dart:io';

import 'package:test/test.dart';

import 'architecture/layer_rules.dart';

void main() {
  group('lib/', () {
    test(
      'should respect the layer dependency rule when scanning every file',
      () {
        final violations = findViolations(_readLibSources());

        // Printing the violations in the failure message tells the developer
        // exactly which import to remove.
        expect(violations, isEmpty, reason: violations.join('\n'));
      },
    );
  });

  group('rule checker on fixtures', () {
    test('should report a violation when a domain file imports Flutter', () {
      final violations = findViolations([
        const SourceFile(
          'domain/street/house_number.dart',
          "import 'package:flutter/foundation.dart';\n",
        ),
      ]);

      expect(violations, hasLength(1));
      expect(violations.single.path, 'domain/street/house_number.dart');
      expect(violations.single.uri, 'package:flutter/foundation.dart');
      expect(violations.single.reason, contains('domain'));
    });

    test(
      'should accept a domain file when it imports only allowed libraries',
      () {
        final violations = findViolations([
          const SourceFile('domain/street/street.dart', '''
import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:tournee_calendriers/domain/shared/clock.dart';

import 'house_number.dart';
'''),
        ]);

        expect(violations, isEmpty);
      },
    );

    test('should report a violation when domain imports an outer layer', () {
      for (final outer in ['application', 'presentation', 'ui', 'bootstrap']) {
        final violations = findViolations([
          SourceFile(
            'domain/street/street.dart',
            "import 'package:tournee_calendriers/$outer/x.dart';\n",
          ),
        ]);

        expect(violations, hasLength(1), reason: outer);
      }
    });

    test('should report a violation when domain imports infrastructure', () {
      final violations = findViolations([
        const SourceFile(
          'domain/street/street.dart',
          "import 'package:tournee_calendriers/infrastructure/x.dart';\n",
        ),
      ]);

      expect(violations, hasLength(1));
    });

    test(
      'should report a violation when domain uses dart:io or dart:async',
      () {
        final violations = findViolations([
          const SourceFile(
            'domain/street/street.dart',
            "import 'dart:io';\nimport 'dart:async';\n",
          ),
        ]);

        expect(violations.map((v) => v.uri), ['dart:io', 'dart:async']);
      },
    );

    test(
      'should resolve a relative import when it climbs to another layer',
      () {
        final violations = findViolations([
          const SourceFile(
            'domain/street/street.dart',
            "import '../../infrastructure/firestore/street_adapter.dart';\n",
          ),
        ]);

        expect(violations, hasLength(1));
        expect(
          violations.single.uri,
          '../../infrastructure/firestore/street_adapter.dart',
        );
      },
    );

    test('should check export and part directives like imports', () {
      final violations = findViolations([
        const SourceFile(
          'domain/street/street.dart',
          "export 'package:flutter/widgets.dart';\n"
              "part '../../ui/street_part.dart';\n",
        ),
      ]);

      expect(violations, hasLength(2));
    });

    test('should check every URI of a conditional import', () {
      final violations = findViolations([
        const SourceFile('domain/street/street.dart', '''
import 'house_number.dart'
    if (dart.library.io) 'package:flutter/foundation.dart';
'''),
      ]);

      expect(violations.map((v) => v.uri), ['package:flutter/foundation.dart']);
    });

    test('should accept application when it imports domain and dart:async', () {
      final violations = findViolations([
        const SourceFile('application/use_cases/mark_house.dart', '''
import 'dart:async';

import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
'''),
      ]);

      expect(violations, isEmpty);
    });

    test('should report a violation when application imports outward', () {
      for (final uri in [
        'package:tournee_calendriers/infrastructure/x.dart',
        'package:tournee_calendriers/presentation/x.dart',
        'package:tournee_calendriers/ui/x.dart',
        'package:tournee_calendriers/bootstrap/x.dart',
        'package:flutter/foundation.dart',
        'package:http/http.dart',
      ]) {
        final violations = findViolations([
          SourceFile('application/use_cases/mark_house.dart', "import '$uri';"),
        ]);

        expect(violations, hasLength(1), reason: uri);
      }
    });

    test(
      'should accept presentation when it imports Riverpod and inner layers',
      () {
        final violations = findViolations([
          const SourceFile('presentation/street/street_notifier.dart', '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/mark_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
'''),
        ]);

        expect(violations, isEmpty);
      },
    );

    test(
      'should report a violation when presentation imports widgets or adapters',
      () {
        for (final uri in [
          'package:flutter/widgets.dart',
          'package:tournee_calendriers/infrastructure/x.dart',
          'package:tournee_calendriers/ui/x.dart',
          'package:tournee_calendriers/bootstrap/x.dart',
        ]) {
          final violations = findViolations([
            SourceFile(
              'presentation/street/street_notifier.dart',
              "import '$uri';",
            ),
          ]);

          expect(violations, hasLength(1), reason: uri);
        }
      },
    );

    test(
      'should accept ui when it imports Flutter, presentation and domain',
      () {
        final violations = findViolations([
          const SourceFile('ui/street/street_screen.dart', '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
'''),
        ]);

        expect(violations, isEmpty);
      },
    );

    test('should report a violation when ui skips presentation', () {
      for (final uri in [
        'package:tournee_calendriers/application/use_cases/mark_house.dart',
        'package:tournee_calendriers/infrastructure/x.dart',
        'package:tournee_calendriers/bootstrap/x.dart',
      ]) {
        final violations = findViolations([
          SourceFile('ui/street/street_screen.dart', "import '$uri';"),
        ]);

        expect(violations, hasLength(1), reason: uri);
      }
    });

    test(
      'should accept infrastructure when it imports inner layers and SDKs',
      () {
        final violations = findViolations([
          const SourceFile(
            'infrastructure/firestore/street_repository.dart',
            '''
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
''',
          ),
        ]);

        expect(violations, isEmpty);
      },
    );

    test(
      'should report a violation when infrastructure imports outer layers',
      () {
        for (final uri in [
          'package:tournee_calendriers/presentation/x.dart',
          'package:tournee_calendriers/ui/x.dart',
          'package:tournee_calendriers/bootstrap/x.dart',
        ]) {
          final violations = findViolations([
            SourceFile('infrastructure/firestore/x.dart', "import '$uri';"),
          ]);

          expect(violations, hasLength(1), reason: uri);
        }
      },
    );

    test(
      'should accept bootstrap and main.dart when they import every layer',
      () {
        const everything = '''
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tournee_calendriers/application/x.dart';
import 'package:tournee_calendriers/bootstrap/x.dart';
import 'package:tournee_calendriers/domain/x.dart';
import 'package:tournee_calendriers/infrastructure/x.dart';
import 'package:tournee_calendriers/presentation/x.dart';
import 'package:tournee_calendriers/ui/x.dart';
''';
        final violations = findViolations([
          const SourceFile('bootstrap/bootstrap.dart', everything),
          const SourceFile('main.dart', everything),
        ]);

        expect(violations, isEmpty);
      },
    );

    test('should report a violation when ui imports a backend package', () {
      for (final uri in [
        'package:cloud_firestore/cloud_firestore.dart',
        'package:firebase_auth/firebase_auth.dart',
        'package:http/http.dart',
        'package:shared_preferences/shared_preferences.dart',
      ]) {
        final violations = findViolations([
          SourceFile('ui/street/street_screen.dart', "import '$uri';"),
        ]);

        expect(violations, hasLength(1), reason: uri);
        expect(violations.single.reason, contains('infrastructure'));
      }
    });

    test('should allow MapLibre only in ui/map and infrastructure/maplibre_offline', () {
      const maplibre = "import 'package:maplibre_gl/maplibre_gl.dart';";

      final violations = findViolations([
        const SourceFile('ui/map/tournee_map.dart', maplibre),
        const SourceFile(
          'infrastructure/maplibre_offline/store.dart',
          maplibre,
        ),
        const SourceFile('ui/street/street_screen.dart', maplibre),
        const SourceFile('infrastructure/firestore/x.dart', maplibre),
        const SourceFile('bootstrap/bootstrap.dart', maplibre),
      ]);

      expect(violations.map((v) => v.path), [
        'ui/street/street_screen.dart',
        'infrastructure/firestore/x.dart',
        'bootstrap/bootstrap.dart',
      ]);
    });

    test('should report a violation when a file sits outside every layer', () {
      final violations = findViolations([
        const SourceFile('helpers/strings.dart', ''),
      ]);

      expect(violations, hasLength(1));
      expect(violations.single.path, 'helpers/strings.dart');
      expect(violations.single.reason, contains('outside'));
    });

    test('should report a violation when an import targets no known layer', () {
      final violations = findViolations([
        const SourceFile(
          'bootstrap/bootstrap.dart',
          "import 'package:tournee_calendriers/helpers/strings.dart';",
        ),
      ]);

      expect(violations, hasLength(1));
    });

    test('should ignore directive-like text when it is inside a comment', () {
      final violations = findViolations([
        const SourceFile('domain/street/street.dart', '''
// import 'package:flutter/widgets.dart';
/// Not a directive: import 'package:flutter/widgets.dart';
/*
import 'package:flutter/widgets.dart';
*/
'''),
      ]);

      expect(violations, isEmpty);
    });
  });
}

/// Reads every Dart file under `lib/`, with paths relative to `lib/`.
///
/// `flutter test` runs with the project root as the working directory, which
/// is why the relative `lib` path works here.
List<SourceFile> _readLibSources() {
  final lib = Directory('lib');
  return [
    for (final entity in lib.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        SourceFile(
          entity.path.substring(lib.path.length + 1).replaceAll(r'\', '/'),
          entity.readAsStringSync(),
        ),
  ];
}
