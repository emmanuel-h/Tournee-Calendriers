// The new streets whose Firestore writes are not all sent yet (#104), on a
// real temporary folder: what is kept must be there after a restart (a new
// adapter on the same folder).
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_unfinished_streets.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_json_mapper.dart';

import 'stored_street_fixtures.dart';

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('unfinished_test');
  });

  tearDown(() => folder.delete(recursive: true));

  /// The folder of the adapter, not made yet, as on a first launch.
  Directory streets() => Directory('${folder.path}/unfinished/t49/2026');

  /// An adapter on the folder; a new one simulates a restart of the app.
  LocalUnfinishedStreets restart() => LocalUnfinishedStreets(streets());

  List<String> fileNames() =>
      [for (final entity in streets().listSync()) entity.uri.pathSegments.last]
        ..sort();

  test('should find none and make no folder when it is new', () async {
    expect(await restart().load(), isEmpty);
    expect(streets().existsSync(), isFalse);
  });

  test('should find a street kept, whole, after a restart', () async {
    await restart().keep(richStreet);

    final found = await restart().load();

    expect(found, hasLength(1));
    expectSameStreet(found.single, richStreet);
  });

  test('should keep each street in a file of its own, as the phone '
      'storage writes it', () async {
    await restart().keep(richStreet);
    await restart().keep(manualStreet);

    expect(fileNames(), [
      '${richStreet.id.value}.json',
      '${manualStreet.id.value}.json',
    ]);
    final file = File(
      '${streets().path}/${Uri.encodeComponent(richStreet.id.value)}.json',
    );
    expect(jsonDecode(file.readAsStringSync()), streetToJson(richStreet));
  });

  test('should forget a street kept, and only that one', () async {
    final unfinished = restart();
    await unfinished.keep(richStreet);
    await unfinished.keep(manualStreet);

    await unfinished.forget(richStreet.id);

    final found = await restart().load();
    expect(found.map((street) => street.id), [manualStreet.id]);
  });

  test('should forget a street that is not kept without failing', () async {
    final unfinished = restart();
    await unfinished.keep(richStreet);

    await unfinished.forget(StreetId('autre'));

    expect(await restart().load(), hasLength(1));
  });

  test('should forget a street asked right after it was kept', () async {
    final unfinished = restart();

    // Not awaited one by one: the forget waits for the keep.
    await Future.wait([
      unfinished.keep(richStreet),
      unfinished.forget(richStreet.id),
    ]);

    expect(await restart().load(), isEmpty);
  });

  test('should skip a file that cannot be read, and the leftovers of a '
      'killed write', () async {
    await restart().keep(richStreet);
    File('${streets().path}/broken.json').writeAsStringSync('{not json');
    File('${streets().path}/latin1.json').writeAsBytesSync([0xff, 0xfe]);
    File('${streets().path}/other.json.tmp').writeAsStringSync('{}');
    Directory('${streets().path}/folder.json').createSync();

    final found = await restart().load();

    expect(found.map((street) => street.id), [richStreet.id]);
  });

  test('should let a later write go when one fails', () async {
    final unfinished = restart();
    await unfinished.keep(richStreet);
    // A folder where the file goes: the rename over it fails.
    final file = File(
      '${streets().path}/${Uri.encodeComponent(manualStreet.id.value)}.json',
    );
    Directory(file.path).createSync();

    await expectLater(
      unfinished.keep(manualStreet),
      throwsA(isA<FileSystemException>()),
    );
    await unfinished.forget(richStreet.id);

    expect(await restart().load(), isEmpty);
  });
}
