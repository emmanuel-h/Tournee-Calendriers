import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/atomic_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_json_mapper.dart';

/// The [StreetRepository] of M1: the streets live on the phone, one JSON
/// file per street in [directory] (PLAN §6.3), until Firestore replaces
/// this storage in M2 behind the same port. No network, ever.
///
/// - **One file per street.** A commune can hold ≈ 300 streets and 6 000
///   numbers (a few MB of JSON): one file for all would be rewritten whole
///   at every tap. A street's file is a few kB to ≈ 100 kB.
/// - **Memory first.** Every file is read once, at the first call, into a
///   map that then answers every read; a write updates the map at once,
///   tells the listeners, and then writes the file. So the screens never
///   wait for the disk, and a tap right after another reads the street the
///   first one made.
/// - **Safe writes.** Each file is written to a temporary file then renamed
///   (see [writeAtomically]), so a kill mid-write leaves the old street, not
///   a broken file. Writes run one after the other, in the order they were
///   asked, so an older save never lands after a newer one.
/// - A file that cannot be read (written by a newer version, or damaged) is
///   skipped and left untouched on the disk, rather than stopping the app.
final class LocalStreetRepository implements StreetRepository {
  LocalStreetRepository(this.directory);

  /// The folder holding the street files; created when missing.
  final Directory directory;

  /// The streets read from [directory], loaded once. A `Future` kept in a
  /// field: every caller waits for the same single load.
  Future<Map<StreetId, Street>>? _loaded;

  /// The id of each street written, as soon as it is in memory. Broadcast:
  /// any number of screens may listen. `sync: true` tells them during the
  /// write itself, before anything else can run.
  final _written = StreamController<StreetId>.broadcast(sync: true);

  /// The last write asked; the next one starts when it ends.
  Future<void> _lastWrite = Future.value();

  @override
  Future<Street?> find(StreetId id) async => (await _streets())[id];

  @override
  Future<Street?> findByBanId(BanStreetId banId) async {
    for (final street in (await _streets()).values) {
      if (street.banId == banId) return street;
    }
    return null;
  }

  @override
  Stream<Street?> watch(StreetId id) =>
      _observe((streets) => streets[id], (written) => written == id);

  @override
  Stream<List<Street>> watchAll() => _observe(
    (streets) => List.unmodifiable([
      for (final street in streets.values)
        if (!street.isDeleted) street,
    ]),
    (_) => true,
  );

  @override
  Future<void> add(Street street) => _put(street);

  /// Saves the whole [street]: a file holds a street, so the [change] is not
  /// needed here (Firestore will write only its fields).
  @override
  Future<void> save(Street street, StreetChange change) => _put(street);

  Future<void> _put(Street street) async {
    final streets = await _streets();
    streets[street.id] = street;
    _written.add(street.id);
    // The text is made now, so a later change cannot slip into this write.
    final text = jsonEncode(streetToJson(street));
    final write = _lastWrite.then(
      (_) => writeAtomically(_fileOf(street.id), text),
    );
    // A failed write must not block the ones after it; the caller still
    // gets its error through `write`.
    _lastWrite = write.then<void>((_) {}, onError: (Object _) {});
    await write;
  }

  Future<Map<StreetId, Street>> _streets() => _loaded ??= _load();

  Future<Map<StreetId, Street>> _load() async {
    await directory.create(recursive: true);
    final streets = <StreetId, Street>{};
    await for (final entity in directory.list()) {
      // `.json.tmp` files, left by a killed write, end in `.tmp`.
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final street = streetFromJson(jsonDecode(await entity.readAsString()));
        streets[street.id] = street;
      } on FormatException {
        // Unreadable: skipped, and kept on the disk for a later version.
      } on FileSystemException {
        // Not valid UTF-8, or not readable: the same.
      }
    }
    return streets;
  }

  /// The file of the street [id]. The id is percent-encoded, so whatever it
  /// holds it stays one file name in [directory].
  File _fileOf(StreetId id) => File(
    '${directory.path}${Platform.pathSeparator}'
    '${Uri.encodeComponent(id.value)}.json',
  );

  /// A stream giving [read] of the streets once loaded, then again after
  /// each write that [concerns] it.
  Stream<T> _observe<T>(
    T Function(Map<StreetId, Street> streets) read,
    bool Function(StreetId written) concerns,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<StreetId>? subscription;
    controller = StreamController<T>(
      onListen: () => unawaited(
        _streets().then((streets) {
          // The listener may have left while the files were being read.
          if (!controller.hasListener) return;
          controller.add(read(streets));
          subscription = _written.stream
              .where(concerns)
              .listen((_) => controller.add(read(streets)));
        }, onError: controller.addError),
      ),
      // A listener that leaves stops the updates and frees the stream.
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}
