import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_agenda.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/shared/calendar_day.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/reminders/reminders_notifier.dart';

/// « À repasser » and its row on Accueil. `autoDispose`: it follows the
/// streets only while one of them shows.
final comeBacksProvider =
    NotifierProvider.autoDispose<ComeBacksNotifier, ComeBacksView>(
      ComeBacksNotifier.new,
    );

/// Follows every « repasser » of the open secteur (`ObserveComeBacks`) and
/// its team (`ObserveTeam`, which names who set each), from the phone's
/// copy, offline too, and orders them by day (`ComeBackAgenda`). The 🔔
/// says which ones this phone rings for (`PlanReminders`).
final class ComeBacksNotifier extends Notifier<ComeBacksView> {
  /// The last « repasser » read, null until the first arrive.
  List<ComeBackEntry>? _entries;
  Sector? _team;

  @override
  ComeBacksView build() {
    // Riverpod keeps the notifier when it builds again (another secteur
    // opened): nothing of the old one may stay.
    _entries = null;
    _team = null;
    // The 🔔 follows the switch « Rappels pour repasser ».
    ref.watch(remindersProvider.select((state) => state.on));
    final entries = ref
        .watch(observeComeBacksProvider)()
        .listen(
          (entries) {
            _entries = entries;
            state = _render();
          },
          // The streets can no longer be read (the member left the
          // secteur): nothing to come back to.
          onError: (Object _) {
            _entries = const [];
            state = _render();
          },
        );
    ref.onDispose(entries.cancel);
    final sector = ref.watch(currentSectorProvider.select((s) => s?.id));
    if (sector != null) {
      final team = ref.watch(observeTeamProvider)(sector).listen(
        (team) {
          _team = team;
          state = _render();
        },
        // The team cannot be read: the rows still show, without names.
        onError: (Object _) {},
      );
      ref.onDispose(team.cancel);
    }
    return _render();
  }

  ComeBacksView _render() {
    final entries = _entries;
    if (entries == null) return ComeBacksView.reading;
    // The clock tells « today »; reading it here, and not
    // `DateTime.now()`, lets the tests fix the day.
    final today = CalendarDay.of(ref.read(clockProvider).now().toLocal());
    final agenda = ComeBackAgenda.of(entries, today: today);
    final plan = ref.read(planRemindersProvider)(entries);
    ComeBackRow row(ComeBackEntry entry) => _rowOf(entry, today, plan);
    return ComeBacksView(
      loading: false,
      count: agenda.count,
      next: switch (agenda.next) {
        final next? => row(next),
        null => null,
      },
      sections: [
        for (final day in agenda.days)
          ComeBackSection(
            ComeBackOnDay(
              ComeBackDay(day.day, DayFromToday.of(day.day, today: today)),
            ),
            day.entries.map(row),
          ),
        if (agenda.anyTime.isNotEmpty)
          ComeBackSection(const ComeBackAnyTime(), agenda.anyTime.map(row)),
      ],
    );
  }

  ComeBackRow _rowOf(
    ComeBackEntry entry,
    CalendarDay today,
    ReminderPlan plan,
  ) {
    final day = entry.comeBack.day;
    return ComeBackRow(
      place: entry.place,
      streetName: entry.streetName.text,
      number: entry.place.number.label,
      door: entry.place.door?.label.text,
      day: day == null
          ? null
          : ComeBackDay(day, DayFromToday.of(day, today: today)),
      hour: entry.comeBack.hour,
      by: _authorOf(entry),
      rings: plan.rings(entry.place),
    );
  }

  /// Who set [entry], as « Modifié par » names them (PLAN §5.7): the
  /// member on the phone, a member of the open secteur, or nobody known.
  ChangeAuthor? _authorOf(ComeBackEntry entry) {
    final by = entry.setBy?.by;
    if (by == null) return null;
    if (by == ref.read(readCurrentMemberProvider)()) {
      return const ChangedByMe();
    }
    return switch (_team?.memberOf(by)) {
      final member? => ChangedByMember(member.name.text),
      null => null,
    };
  }
}
