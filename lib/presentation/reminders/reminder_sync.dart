import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/reminders.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/reminders/reminders_notifier.dart';

/// Keeps the phone's reminders in step with the open secteur's « repasser »
/// while the app runs (PLAN §5.17). Built again when another secteur (or
/// none) opens, since the streets it watches follow it, and when the switch
/// « Rappels pour repasser » changes: each time, the streets are read again
/// and the reminders replaced. The app's root keeps it alive.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  // `select`: only the switch matters here, not whether Android allows.
  ref.watch(remindersProvider.select((state) => state.on));
  final sync = ReminderSync(ref.watch(scheduleRemindersProvider));
  final streets = ref
      .watch(observeComeBacksProvider)()
      .listen(
        sync.update,
        // The streets can no longer be read (the member left the
        // secteur): nothing to remind of.
        onError: (Object _) => sync.update(const []),
      );
  ref.onDispose(streets.cancel);
  return sync;
});

/// Replaces the reminders with those of the latest « repasser », one
/// replacement at a time: two running together could leave some of the
/// first behind. « repasser » given while one runs wait, and only the
/// latest are scheduled after it.
final class ReminderSync {
  ReminderSync(this._schedule);

  final ScheduleReminders _schedule;

  /// The « repasser » still to schedule once the running replacement ends.
  List<ComeBackEntry>? _waiting;
  Future<void>? _running;

  /// Schedules the reminders of [entries].
  Future<void> update(List<ComeBackEntry> entries) {
    _waiting = entries;
    return _running ??= _run();
  }

  Future<void> _run() async {
    try {
      var entries = _waiting;
      while (entries != null) {
        _waiting = null;
        try {
          await _schedule(entries);
        } on Exception {
          // Android refused (a plugin error): nothing the member can act
          // on, and the next change of the streets tries again.
        }
        entries = _waiting;
      }
    } finally {
      _running = null;
    }
  }
}
