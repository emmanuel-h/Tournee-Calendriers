import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/phone_cache_reset.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/json_file.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/cache_reset_json_mapper.dart';

/// The [PhoneCacheReset] of the app: Firestore's copy on the phone is
/// emptied (`clearPersistence`) at a start, before anything reads it, once
/// a secteur was forgotten (PLAN §6.3, §8.3). Where it stands is kept in
/// `cache_reset.json` ([CacheResetStep]), so the request outlives a kill.
///
/// Emptying the copy also throws away the writes still queued in it: marks
/// made offline, a tournée validated offline, a secteur left offline. So
/// the copy is emptied only once the server is known to have every change
/// made on this phone: after a request, and each time the app is hidden
/// ([appHidden]: a phone is killed in the background), the step goes back
/// to [CacheResetStep.waiting] until Firestore says all is sent
/// (`waitForPendingWrites`); only then is it [CacheResetStep.due].
///
/// Firestore is reached through two functions rather than the database
/// itself, so that the tests play them: [_waitForPendingWrites] ends once
/// the server has every write made so far (offline, it waits);
/// [_clearPersistence] fails once Firestore has started.
final class FirestoreCacheReset implements PhoneCacheReset {
  FirestoreCacheReset._(
    this._file,
    this._step,
    this._waitForPendingWrites,
    this._clearPersistence,
  );

  /// Reads where the reset stands from [file]. A missing or unreadable
  /// file means nothing asked: the copy stays, which loses nothing.
  static Future<FirestoreCacheReset> load(
    File file, {
    required Future<void> Function() waitForPendingWrites,
    required Future<void> Function() clearPersistence,
  }) async {
    final stored = JsonFile(file);
    var step = CacheResetStep.none;
    try {
      if (await stored.read() case final json?) {
        step = cacheResetFromJson(json);
      }
    } on FormatException {
      // Not JSON, or not our schema: nothing asked.
    }
    return FirestoreCacheReset._(
      stored,
      step,
      waitForPendingWrites,
      clearPersistence,
    );
  }

  final JsonFile _file;
  CacheResetStep _step;
  final Future<void> Function() _waitForPendingWrites;
  final Future<void> Function() _clearPersistence;

  /// Counts the waits for the server: only the last one asked may say
  /// [CacheResetStep.due], since an older one does not cover the writes
  /// made after it started.
  var _waits = 0;

  /// The last wait for the server, from its start to the step it wrote.
  Future<void> _lastWait = Future.value();

  /// Where the reset stands now.
  CacheResetStep get step => _step;

  /// Ends once the last wait for the server has ended and written its
  /// step (or failed). Nothing waits for it in the app; the tests do.
  Future<void> get lastWait => _lastWait;

  @override
  void scheduleAtNextStart() => _waitForServer();

  /// The app went to the background, where Android may kill it: when a
  /// reset is asked, it waits again for the server to have the changes
  /// made since the last check.
  void appHidden() {
    if (_step != CacheResetStep.none) _waitForServer();
  }

  /// At start-up, before anything asks Firestore anything: empties its copy
  /// when a reset is [CacheResetStep.due] and the phone [online] (offline,
  /// the copy of the secteurs still held must stay, for the day without
  /// network, PLAN §7). Then [afterReset] runs (the composition root
  /// forgets the downloads, so the open secteur is downloaded again) and
  /// nothing is asked any more. Returns whether the copy was emptied.
  ///
  /// Never fails: a copy that cannot be emptied (Firestore already started,
  /// as when the instrumented suite starts the app again in one process)
  /// stays, and the next start tries again.
  Future<bool> resetIfDue({
    required Future<bool> Function() online,
    required Future<void> Function() afterReset,
  }) async {
    if (_step != CacheResetStep.due || !await online()) return false;
    try {
      await _clearPersistence();
      await afterReset();
      await _save(CacheResetStep.none);
      return true;
    } on Object catch (error) {
      debugPrint('Firestore copy not emptied: $error');
      return false;
    }
  }

  /// [CacheResetStep.waiting] now, [CacheResetStep.due] once the server has
  /// every write made so far, unless another wait started meanwhile.
  void _waitForServer() {
    final wait = ++_waits;
    unawaited(
      _lastWait = _logged(() async {
        await _save(CacheResetStep.waiting);
        await _waitForPendingWrites();
        if (wait == _waits) await _save(CacheResetStep.due);
      }),
    );
  }

  Future<void> _save(CacheResetStep step) {
    _step = step;
    return _file.write(cacheResetToJson(step));
  }

  /// Runs [task], logging its failure rather than letting it reach the
  /// app: the reset is asked again at the next forgotten secteur, and a
  /// failed wait leaves it [CacheResetStep.waiting], which empties nothing.
  Future<void> _logged(Future<void> Function() task) async {
    try {
      await task();
    } on Object catch (error) {
      debugPrint('Firestore copy reset not recorded: $error');
    }
  }
}
