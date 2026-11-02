import 'dart:convert';
import 'dart:io';

import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/unfinished_streets.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/atomic_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_json_mapper.dart';

/// The [UnfinishedStreets] of one campaign on the phone: one JSON file per
/// street in [directory], in the form of the phone's own streets
/// ([streetToJson]). No network, ever.
///
/// One file per street, as `LocalStreetRepository`: a street of 300
/// numbers is ≈ 100 kB, and an import adds dozens of streets in a row, so
/// one file for all would be written again whole for each. The folder is
/// empty nearly always: a file lives the second or two a street takes to
/// be handed to Firestore.
final class LocalUnfinishedStreets implements UnfinishedStreets {
  LocalUnfinishedStreets(this.directory);

  /// The folder of the files; made at the first [keep].
  final Directory directory;

  /// The last write asked; the next one starts when it ends, so a [forget]
  /// never lands before the [keep] of the same street.
  Future<void> _lastWrite = Future.value();

  /// Reads every file of [directory]. A file that cannot be read (damaged,
  /// or written by a newer version) is skipped: its street stays as
  /// Firestore has it, and the user can add the missing numbers.
  @override
  Future<List<Street>> load() async {
    // A sync check: `Directory.exists` would cost a round trip to another
    // thread (the `avoid_slow_async_io` lint).
    if (!directory.existsSync()) return const [];
    final streets = <Street>[];
    await for (final entity in directory.list()) {
      // `.json.tmp` files, left by a killed write, end in `.tmp`.
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        streets.add(streetFromJson(jsonDecode(await entity.readAsString())));
      } on FormatException {
        // Not JSON, or not a street: skipped.
      } on FileSystemException {
        // Not valid UTF-8: the same.
      }
    }
    return streets;
  }

  @override
  Future<void> keep(Street street) {
    // The text is made now, so a later change cannot slip into this write.
    final text = jsonEncode(streetToJson(street));
    return _queue(() async {
      await directory.create(recursive: true);
      await writeAtomically(_fileOf(street.id), text);
    });
  }

  @override
  Future<void> forget(StreetId id) => _queue(() async {
    final file = _fileOf(id);
    if (file.existsSync()) await file.delete();
  });

  /// Runs [task] on the disk once the tasks already queued are done.
  Future<void> _queue(Future<void> Function() task) {
    final run = _lastWrite.then((_) => task());
    // A failed task must not block the ones after it; the caller still
    // gets its error through `run`.
    _lastWrite = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// The file of the street [id]. The id is percent-encoded, so whatever it
  /// holds it stays one file name in [directory].
  File _fileOf(StreetId id) => File(
    '${directory.path}${Platform.pathSeparator}'
    '${Uri.encodeComponent(id.value)}.json',
  );
}
