// Behaviour of tool/write_firebase_config.sh, which CI runs to write the
// gitignored Firebase settings from its secrets.
//
// Each test runs the script in a throwaway project folder with only the
// environment variables it sets, as CI does.
@TestOn('linux || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('write_firebase_config_');
    Directory('${project.path}/lib/bootstrap').createSync(recursive: true);
    Directory('${project.path}/android/app').createSync(recursive: true);
  });

  tearDown(() => project.deleteSync(recursive: true));

  File options() => File('${project.path}/lib/bootstrap/firebase_options.dart');
  File services() => File('${project.path}/android/app/google-services.json');

  test('should write both files when both secrets are set', () {
    final result = _run(project, {
      'FIREBASE_OPTIONS_DART': base64.encode(utf8.encode('// options\n')),
      'GOOGLE_SERVICES_JSON': base64.encode(utf8.encode('{"a": 1}\n')),
    });

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(options().readAsStringSync(), '// options\n');
    expect(services().readAsStringSync(), '{"a": 1}\n');
  });

  test('should fail and name the secret when one is missing', () {
    final result = _run(project, {
      'FIREBASE_OPTIONS_DART': base64.encode(utf8.encode('// options\n')),
    });

    expect(result.exitCode, 1);
    expect(result.stderr, contains('GOOGLE_SERVICES_JSON is not set'));
    expect(services().existsSync(), isFalse);
  });

  test('should fail and leave no file when a secret is not base64', () {
    final result = _run(project, {
      'FIREBASE_OPTIONS_DART': 'not base64 !',
      'GOOGLE_SERVICES_JSON': base64.encode(utf8.encode('{}')),
    });

    expect(result.exitCode, 1);
    expect(result.stderr, contains('FIREBASE_OPTIONS_DART is not valid'));
    expect(options().existsSync(), isFalse);
  });
}

/// Runs the script of this repository with [project] as the working
/// directory and only [environment] (plus PATH, to find bash and base64).
ProcessResult _run(Directory project, Map<String, String> environment) =>
    Process.runSync(
      'bash',
      [File('tool/write_firebase_config.sh').absolute.path],
      workingDirectory: project.path,
      environment: {'PATH': Platform.environment['PATH']!, ...environment},
      includeParentEnvironment: false,
    );
