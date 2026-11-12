import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/reminder_preferences.dart';
import 'package:tournee_calendriers/application/ports/reminder_scheduler.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

// « À repasser » and the reminders to come back (PLAN §5.17): everything
// on the phone, offline too.

/// Every « repasser » of the open secteur (houses, doors, buildings), now
/// and after each change to its streets, read from the phone's copy. None
/// while no secteur is open. Streets in the Corbeille are left out.
final class ObserveComeBacks {
  const ObserveComeBacks(this._streets);

  final StreetRepository _streets;

  Stream<List<ComeBackEntry>> call() =>
      _streets.watchAll().map(ComeBackEntry.allOf);
}

/// The reminders this phone rings for [ComeBackEntry]s now: those the
/// member on the phone set, as [ReminderPlan] works them out; none while
/// « Rappels pour repasser » is off.
final class PlanReminders {
  const PlanReminders(this._preferences, this._identity, this._clock);

  final ReminderPreferences _preferences;
  final IdentityProvider _identity;
  final Clock _clock;

  ReminderPlan call(List<ComeBackEntry> entries) => _preferences.on
      ? ReminderPlan.of(
          entries,
          member: _identity.currentMember,
          now: _clock.now(),
        )
      : ReminderPlan.none;
}

/// Replaces the phone's reminders with those of [entries] (see
/// [PlanReminders]): run again each time the streets, the open secteur or
/// the switch change, so a teammate who marks the house, changes its time
/// or clears it cancels its reminder, and a secteur closed leaves none.
final class ScheduleReminders {
  const ScheduleReminders(this._plan, this._scheduler);

  final PlanReminders _plan;
  final ReminderScheduler _scheduler;

  Future<void> call(List<ComeBackEntry> entries) =>
      _scheduler.replaceAll(_plan(entries).reminders);
}

/// Whether « Rappels pour repasser » is on.
final class ReadRemindersOn {
  const ReadRemindersOn(this._preferences);

  final ReminderPreferences _preferences;

  bool call() => _preferences.on;
}

/// Whether Android lets the reminders ring: « Bloqués par Android » when
/// it does not.
final class ReadRemindersAllowed {
  const ReadRemindersAllowed(this._scheduler);

  final ReminderScheduler _scheduler;

  Future<bool> call() => _scheduler.areAllowed();
}

/// The switch « Rappels pour repasser »: keeps [on]. Turned on, it asks
/// Android for the permission (which it shows only while it may). Answers
/// whether Android lets them ring.
final class SwitchReminders {
  const SwitchReminders(this._preferences, this._scheduler);

  final ReminderPreferences _preferences;
  final ReminderScheduler _scheduler;

  Future<bool> call({required bool on}) async {
    await _preferences.setOn(on);
    if (!on) return _scheduler.areAllowed();
    await _preferences.markPermissionAsked();
    return _scheduler.askPermission();
  }
}

/// Asks Android for the permission the first time the member gives a
/// « repasser » a day (PLAN §5.17), never at launch; once only, and not
/// while the switch is off.
final class AskForRemindersOnce {
  const AskForRemindersOnce(this._preferences, this._scheduler);

  final ReminderPreferences _preferences;
  final ReminderScheduler _scheduler;

  Future<void> call() async {
    if (!_preferences.on || _preferences.permissionAsked) return;
    await _preferences.markPermissionAsked();
    await _scheduler.askPermission();
  }
}

/// « Réglages » of « Bloqués par Android »: Android's notification
/// settings of the app.
final class OpenReminderSettings {
  const OpenReminderSettings(this._scheduler);

  final ReminderScheduler _scheduler;

  Future<void> call() => _scheduler.openSettings();
}

/// Where the reminders tapped lead: first the one that launched the app,
/// if one did, then each one tapped while it runs.
final class FollowReminderTaps {
  const FollowReminderTaps(this._scheduler);

  final ReminderScheduler _scheduler;

  // `async*` makes a stream: `yield` gives one value, `yield*` every value
  // of another stream, in turn.
  Stream<ReminderTarget> call() async* {
    if (await _scheduler.launchTarget() case final target?) yield target;
    yield* _scheduler.taps;
  }
}
