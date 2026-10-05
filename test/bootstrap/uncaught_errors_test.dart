import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/bootstrap/uncaught_errors.dart';

void main() {
  test('should tell the user and handle the error when a file could not be '
      'written', () {
    var told = 0;

    final handled = handleUncaughtError(
      const FileSystemException('No space left on device', 'streets/a.json'),
      onSaveFailed: () => told++,
    );

    expect(handled, isTrue);
    expect(told, 1);
  });

  test('should leave any other error to the default handling', () {
    var told = 0;

    final handled = handleUncaughtError(
      StateError('a bug'),
      onSaveFailed: () => told++,
    );

    expect(handled, isFalse);
    expect(told, 0);
  });
}
