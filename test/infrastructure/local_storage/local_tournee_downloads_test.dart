import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_tournee_downloads.dart';

final _t49 = TourneeDownload(
  tournee: TourneeId('t49'),
  downloadedAt: DateTime.utc(2026, 11, 2, 8, 12),
  mapBytes: 6600000,
  area: null,
);

void main() {
  late Directory folder;
  late File file;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('tournee_downloads_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/tournee_downloads.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should know no download when the file does not exist', () async {
    final downloads = await LocalTourneeDownloads.load(file);

    expect(downloads.downloads, isEmpty);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once, tell the change and keep the download on '
      'the phone', () async {
    final downloads = await LocalTourneeDownloads.load(file);
    final told = downloads.changes.first;

    final saving = downloads.save(_t49);
    expect(downloads.downloads, {TourneeId('t49'): _t49});
    await saving;

    expect(await told, {TourneeId('t49'): _t49});
    expect(jsonDecode(file.readAsStringSync()), {
      'version': 1,
      'downloads': [
        {
          'tournee': 't49',
          'at': '2026-11-02T08:12:00.000Z',
          'mapBytes': 6600000,
          'area': null,
        },
      ],
    });
    final reloaded = await LocalTourneeDownloads.load(file);
    expect(reloaded.downloads, {TourneeId('t49'): _t49});
  });

  test('should forget a download and keep that on the phone', () async {
    final downloads = await LocalTourneeDownloads.load(file);
    await downloads.save(_t49);
    final told = downloads.changes.first;

    await downloads.forget(TourneeId('t49'));

    expect(downloads.downloads, isEmpty);
    expect(await told, isEmpty);
    final reloaded = await LocalTourneeDownloads.load(file);
    expect(reloaded.downloads, isEmpty);
  });

  test(
    'should write nothing when forgetting a tournée not downloaded',
    () async {
      final downloads = await LocalTourneeDownloads.load(file);

      await downloads.forget(TourneeId('t12'));

      expect(file.existsSync(), isFalse);
    },
  );

  test('should know no download when the file is unreadable', () async {
    await file.parent.create(recursive: true);
    file.writeAsStringSync('{"version": 9}');

    final downloads = await LocalTourneeDownloads.load(file);

    expect(downloads.downloads, isEmpty);
  });

  test('should know no download when the file is not JSON', () async {
    await file.parent.create(recursive: true);
    file.writeAsStringSync('not json');

    final downloads = await LocalTourneeDownloads.load(file);

    expect(downloads.downloads, isEmpty);
  });
}
