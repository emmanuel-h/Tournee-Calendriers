// Behaviour of tool/check_coverage.sh on small sample projects.
//
// Each test builds a throwaway project folder (a `lib/` tree plus a
// `coverage/lcov.info`), copies the script into it and runs it there with
// bash, exactly as CI runs it from the project root.
@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('check_coverage_');
    _write(project, 'tool/check_coverage.sh', _script());
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('should pass when every gated line is covered', () {
    _write(project, 'lib/domain/street.dart', 'int f() => 1;\n');
    _write(project, 'coverage/lcov.info', '''
SF:lib/domain/street.dart
DA:1,3
end_of_record
''');

    final result = _run(project);

    expect(result.exitCode, 0, reason: _output(result));
    expect(result.stdout, contains('passed'));
    expect(result.stdout, contains('1/1'));
  });

  test('should fail when a gated file has an uncovered line', () {
    _write(project, 'lib/application/use_case.dart', 'int f() => 1;\n');
    _write(project, 'coverage/lcov.info', '''
SF:lib/application/use_case.dart
DA:1,1
DA:2,0
DA:5,0
end_of_record
''');

    final result = _run(project);

    expect(result.exitCode, 1, reason: _output(result));
    expect(
      result.stdout,
      contains('lib/application/use_case.dart  1/3 lines, uncovered: 2,5'),
    );
  });

  test('should fail when any gated folder is below 100 %', () {
    for (final path in [
      'lib/domain/a.dart',
      'lib/application/a.dart',
      'lib/presentation/a.dart',
      'lib/infrastructure/mappers/a.dart',
      'lib/infrastructure/firestore/mappers/a.dart',
    ]) {
      _write(project, path, 'int f() => 1;\n');
      _write(
        project,
        'coverage/lcov.info',
        'SF:$path\nDA:1,0\nend_of_record\n',
      );

      final result = _run(project);

      expect(result.exitCode, 1, reason: '$path\n${_output(result)}');
      File('${project.path}/$path').deleteSync();
    }
  });

  test('should ignore uncovered lines when the file is not gated', () {
    _write(project, 'lib/domain/street.dart', 'int f() => 1;\n');
    _write(project, 'coverage/lcov.info', '''
SF:lib/ui/app.dart
DA:1,0
end_of_record
SF:lib/infrastructure/firestore/street_repository.dart
DA:1,0
end_of_record
SF:lib/bootstrap/bootstrap.dart
DA:1,0
end_of_record
SF:lib/main.dart
DA:1,0
end_of_record
SF:lib/infrastructure/mappers_helper.dart
DA:1,0
end_of_record
SF:lib/domain/street.dart
DA:1,1
end_of_record
''');

    final result = _run(project);

    expect(result.exitCode, 0, reason: _output(result));
  });

  test('should accept absolute paths when lcov uses them', () {
    _write(project, 'lib/domain/street.dart', 'int f() => 1;\n');
    final absolute = project.resolveSymbolicLinksSync();
    _write(project, 'coverage/lcov.info', '''
SF:$absolute/lib/domain/street.dart
DA:1,0
end_of_record
''');

    final result = _run(project);

    expect(result.exitCode, 1, reason: _output(result));
    expect(result.stdout, contains('lib/domain/street.dart  0/1 lines'));
  });

  test('should fail when a gated file with code is loaded by no test', () {
    _write(project, 'lib/domain/street.dart', '''
final class Street {
  int count() {
    return 0;
  }
}
''');
    _write(project, 'coverage/lcov.info', '');

    final result = _run(project);

    expect(result.exitCode, 1, reason: _output(result));
    expect(
      result.stdout,
      contains('lib/domain/street.dart  has code but no test loads it'),
    );
  });

  test('should detect code when a missing file has only an arrow body', () {
    _write(project, 'lib/presentation/view.dart', 'int f() => 1;\n');
    _write(project, 'coverage/lcov.info', '');

    final result = _run(project);

    expect(result.exitCode, 1, reason: _output(result));
  });

  test('should detect code when a missing file has a getter body', () {
    _write(project, 'lib/domain/street.dart', '''
final class Street {
  int get count {
    return 0;
  }
}
''');
    _write(project, 'coverage/lcov.info', '');

    final result = _run(project);

    expect(result.exitCode, 1, reason: _output(result));
  });

  test('should pass when a missing gated file holds only declarations', () {
    _write(project, 'lib/domain/domain.dart', '''
/// Domain layer. A comment with => and f() { } is not code.
library;
''');
    _write(project, 'lib/domain/street_repository.dart', '''
/* Port: () { */
abstract interface class StreetRepository {
  const StreetRepository();

  Future<int> load(String id, {int retries});
}
''');
    _write(project, 'coverage/lcov.info', '');

    final result = _run(project);

    expect(result.exitCode, 0, reason: _output(result));
  });

  test('should ignore a missing file with code when it is not gated', () {
    _write(project, 'lib/ui/app.dart', 'int f() => 1;\n');
    _write(project, 'coverage/lcov.info', '');

    final result = _run(project);

    expect(result.exitCode, 0, reason: _output(result));
  });

  test('should skip a gated file when it matches an excluded pattern', () {
    _write(
      project,
      'tool/check_coverage.sh',
      _script().replaceFirst(
        'EXCLUDED_PATTERNS=(\n',
        "EXCLUDED_PATTERNS=(\n  '^lib/domain/glue/'\n",
      ),
    );
    _write(project, 'lib/domain/glue/sdk.dart', 'int f() => 1;\n');
    _write(project, 'lib/domain/glue_not.dart', 'int f() => 1;\n');
    _write(project, 'coverage/lcov.info', '''
SF:lib/domain/glue/sdk.dart
DA:1,0
end_of_record
SF:lib/domain/glue_not.dart
DA:1,1
end_of_record
''');

    final result = _run(project);

    expect(result.exitCode, 0, reason: _output(result));
  });

  test('should fail with a hint when lcov.info is missing', () {
    final result = _run(project);

    expect(result.exitCode, 2, reason: _output(result));
    expect(result.stderr, contains('flutter test --coverage'));
  });

  test('should read the lcov file when its path is given as argument', () {
    _write(project, 'lib/domain/street.dart', 'int f() => 1;\n');
    _write(project, 'other.info', 'SF:lib/domain/street.dart\nDA:1,0\n');

    final result = _run(project, ['other.info']);

    expect(result.exitCode, 1, reason: _output(result));
  });
}

String _script() => File('tool/check_coverage.sh').readAsStringSync();

void _write(Directory root, String path, String content) {
  File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

ProcessResult _run(Directory project, [List<String> args = const []]) =>
    Process.runSync('bash', [
      'tool/check_coverage.sh',
      ...args,
    ], workingDirectory: project.path);

String _output(ProcessResult result) => '${result.stdout}\n${result.stderr}';
