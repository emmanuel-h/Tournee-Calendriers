import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/retired_files.dart';

void main() {
  late Directory storage;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('retired_files_test');
  });

  tearDown(() => storage.delete(recursive: true));

  File fileAt(String path) => File('${storage.path}/$path');

  test('should delete the streets of the phone with no secteur open, and '
      'the log of where they were moved', () async {
    fileAt('streets/lilas.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    fileAt('moved_streets.json').writeAsStringSync('{}');

    await deleteRetiredFiles(storage);

    expect(Directory('${storage.path}/streets').existsSync(), isFalse);
    expect(fileAt('moved_streets.json').existsSync(), isFalse);
  });

  test('should keep every other file of the storage folder', () async {
    const kept = [
      'member_id',
      'my_tournees.json',
      'settings.json',
      'street_view.json',
      'tournee_downloads.json',
      'open_round.json',
      'unfinished_streets/t49/2026/lilas.json',
    ];
    for (final path in kept) {
      fileAt(path)
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
    }

    await deleteRetiredFiles(storage);

    for (final path in kept) {
      expect(fileAt(path).existsSync(), isTrue, reason: path);
    }
  });

  test('should do nothing when nothing is left to delete', () async {
    await deleteRetiredFiles(storage);

    expect(storage.listSync(), isEmpty);
  });

  test('should leave what it cannot delete for the next start', () async {
    fileAt('streets/lilas.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    // A folder whose entries cannot be removed (a locked storage).
    final streets = '${storage.path}/streets';
    Process.runSync('chmod', ['555', streets]);
    addTearDown(() => Process.runSync('chmod', ['755', streets]));

    await deleteRetiredFiles(storage);

    expect(fileAt('streets/lilas.json').existsSync(), isTrue);
  });
}
