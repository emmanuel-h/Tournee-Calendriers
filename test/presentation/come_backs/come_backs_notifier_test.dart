import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_notifier.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/reminders/reminders_notifier.dart';

import '../../domain/come_back/come_back_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show leaId, manuId, team;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_reminders.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Saturday 24 October 2026 at 14 h on the phone's clock.
final _saturday2pm = DateTime(2026, 10, 24, 14);

final _byLea = ChangeStamp(by: leaId, at: twoPm);
final _byManu = ChangeStamp(by: manuId, at: twoPm);

/// Rue Nationale: 12 today at 19 h (Léa, on the phone), 14 tomorrow at
/// 18 h (Manu).
final _nationale = valueOf(
  Street.create(
    id: nationaleId,
    name: 'Rue Nationale',
    commune: villefranche,
    houses: [
      House(
        number: n('12'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-24', hour: 19),
        lastChange: _byLea,
      ),
      House(
        number: n('14'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-25', hour: 18),
        lastChange: _byManu,
      ),
    ],
  ),
);

/// Rue Pasteur: 5 yesterday at 18 h (Manu); door 51 of the building 8
/// with no time, set by someone no longer in the team.
final _pasteur = valueOf(
  Street.create(
    id: pasteurId,
    name: 'Rue Pasteur',
    commune: villefranche,
    houses: [
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-23', hour: 18),
        lastChange: _byManu,
      ),
      House(
        number: n('8'),
        building: valueOf(
          Building.create(
            style: DoorLabelStyle.floorAndNumber,
            staircases: [
              Staircase(
                name: escA,
                floors: [
                  Floor(
                    level: 5,
                    dwellings: [
                      Dwelling(
                        label: d('51'),
                        status: VisitStatus.comeBack,
                        lastChange: paulAtThree,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeReminderPreferences preferences;
  late ProviderContainer container;

  void phoneWith(List<Street> given, {bool sectorOpen = true}) {
    streets = FakeStreetRepository(given);
    preferences = FakeReminderPreferences();
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        reminderPreferencesProvider.overrideWithValue(preferences),
        identityProvider.overrideWithValue(FakeIdentity(leaId)),
        clockProvider.overrideWithValue(FakeClock(_saturday2pm)),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            sectorOpen
                ? valueOf(MySectors.none.remember(sector49).open(sector49.id))
                : MySectors.none,
          ),
        ),
        sectorRepositoryProvider.overrideWithValue(
          FakeSectorRepository([team()]),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  /// The view once the streets and the team were read; `listen` keeps the
  /// auto-disposed provider alive, as a screen does.
  Future<ComeBacksView> shown() async {
    container.listen(comeBacksProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(comeBacksProvider);
  }

  final today = ComeBackDay(saturday, DayFromToday.today);
  final tomorrow = ComeBackDay(day('2026-10-25'), DayFromToday.tomorrow);
  final yesterday = ComeBackDay(day('2026-10-23'), DayFromToday.yesterday);

  final nationale12 = ComeBackRow(
    place: ComeBackPlace(street: nationaleId, number: n('12')),
    streetName: 'Rue Nationale',
    number: '12',
    day: today,
    hour: 19,
    by: const ChangedByMe(),
    rings: true,
  );

  test('should show nothing before the streets are read', () {
    phoneWith([_nationale]);
    streets.holdWatches = Completer();

    expect(container.read(comeBacksProvider), ComeBacksView.reading);
    expect(ComeBacksView.reading.loading, isTrue);
    expect(ComeBacksView.reading.shown, isFalse);
  });

  test('should group the « repasser » by day, the past at any time', () async {
    phoneWith([_nationale, _pasteur]);

    final view = await shown();

    expect(view.loading, isFalse);
    expect(view.count, 4);
    expect(view.shown, isTrue);
    expect(view.next, nationale12);
    expect(view.sections, [
      ComeBackSection(ComeBackOnDay(today), [nationale12]),
      ComeBackSection(ComeBackOnDay(tomorrow), [
        ComeBackRow(
          place: ComeBackPlace(street: nationaleId, number: n('14')),
          streetName: 'Rue Nationale',
          number: '14',
          day: tomorrow,
          hour: 18,
          by: const ChangedByMember('Manu'),
        ),
      ]),
      ComeBackSection(const ComeBackAnyTime(), [
        ComeBackRow(
          place: ComeBackPlace(street: pasteurId, number: n('5')),
          streetName: 'Rue Pasteur',
          number: '5',
          day: yesterday,
          hour: 18,
          by: const ChangedByMember('Manu'),
        ),
        ComeBackRow(
          place: ComeBackPlace(
            street: pasteurId,
            number: n('8'),
            door: DwellingKey(escA, 5, d('51')),
          ),
          streetName: 'Rue Pasteur',
          number: '8',
          door: '51',
        ),
      ]),
    ]);
    expect(view.anyRings, isTrue);
    expect(view.sections.last.rows.first.isPast, isTrue);
    expect(view.sections.last.rows.last.isPast, isFalse);
    expect(view.sections.first.rows.single.isPast, isFalse);
  });

  test('should ring for nothing while the switch is off', () async {
    phoneWith([_nationale]);
    container.read(remindersProvider);
    await container.read(remindersProvider.notifier).turn(on: false);

    final view = await shown();

    expect(view.sections.first.rows.single.rings, isFalse);
    expect(view.anyRings, isFalse);
  });

  test('should name nobody but the member without a secteur open', () async {
    phoneWith([_nationale], sectorOpen: false);

    final view = await shown();

    expect(view.sections.last.rows.single.by, isNull);
    expect(view.sections.first.rows.single.by, const ChangedByMe());
  });

  test('should show no next when none has a day from today', () async {
    phoneWith([_pasteur]);

    final view = await shown();

    expect(view.next, isNull);
    expect(view.count, 2);
    expect(view.sections, hasLength(1));
  });

  test('should show nothing once the streets cannot be read', () async {
    phoneWith([_nationale]);
    streets.watchError = StateError('removed');

    final view = await shown();

    expect(view.loading, isFalse);
    expect(view.count, 0);
    expect(view.shown, isFalse);
    expect(view.sections, isEmpty);
  });

  test('should still show the rows when the team cannot be read', () async {
    phoneWith([_nationale]);
    container.updateOverrides([
      streetRepositoryProvider.overrideWithValue(streets),
      reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      reminderPreferencesProvider.overrideWithValue(preferences),
      identityProvider.overrideWithValue(FakeIdentity(leaId)),
      clockProvider.overrideWithValue(FakeClock(_saturday2pm)),
      mySectorsStoreProvider.overrideWithValue(
        FakeMySectorsStore(
          valueOf(MySectors.none.remember(sector49).open(sector49.id)),
        ),
      ),
      sectorRepositoryProvider.overrideWithValue(
        FakeSectorRepository([team()])..watchError = StateError('gone'),
      ),
    ]);

    final view = await shown();

    expect(view.count, 2);
    expect(view.sections.last.rows.single.by, isNull);
  });

  group('view values', () {
    test('should compare and print rows by value', () {
      final other = ComeBackRow(
        place: nationale12.place,
        streetName: 'Rue Nationale',
        number: '12',
      );

      expect(nationale12, isNot(other));
      expect(other, other);
      expect(
        other.hashCode,
        ComeBackRow(
          place: nationale12.place,
          streetName: 'Rue Nationale',
          number: '12',
        ).hashCode,
      );
      expect(
        other.toString(),
        'ComeBackRow(ComeBackPlace(nationale, 12), Rue Nationale, 12, null, '
        'null, null, null, rings: false)',
      );
    });

    test('should compare and print headings and sections by value', () {
      expect(ComeBackOnDay(today), ComeBackOnDay(today));
      expect(ComeBackOnDay(today).hashCode, ComeBackOnDay(today).hashCode);
      expect(ComeBackOnDay(today), isNot(ComeBackOnDay(tomorrow)));
      expect(const ComeBackAnyTime(), isNot(ComeBackOnDay(today)));
      expect(
        const ComeBackAnyTime().hashCode,
        const ComeBackAnyTime().hashCode,
      );
      expect(const ComeBackAnyTime().toString(), 'ComeBackAnyTime');
      expect(
        ComeBackOnDay(today).toString(),
        'ComeBackOnDay(ComeBackDay(2026-10-24, today))',
      );
      final section = ComeBackSection(const ComeBackAnyTime(), [nationale12]);
      expect(section, ComeBackSection(const ComeBackAnyTime(), [nationale12]));
      expect(
        section.hashCode,
        ComeBackSection(const ComeBackAnyTime(), [nationale12]).hashCode,
      );
      expect(section, isNot(ComeBackSection(const ComeBackAnyTime(), [])));
      expect(
        section,
        isNot(ComeBackSection(ComeBackOnDay(today), [nationale12])),
      );
      expect(
        ComeBackSection(const ComeBackAnyTime(), const []).toString(),
        'ComeBackSection(ComeBackAnyTime, [])',
      );
    });

    test('should compare and print views by value', () {
      ComeBacksView of({int count = 1, ComeBackRow? next}) => ComeBacksView(
        loading: false,
        count: count,
        next: next,
        sections: [
          ComeBackSection(const ComeBackAnyTime(), [nationale12]),
        ],
      );

      expect(of(), of());
      expect(of().hashCode, of().hashCode);
      expect(of(), isNot(of(count: 2)));
      expect(of(), isNot(of(next: nationale12)));
      expect(of(), isNot(ComeBacksView.reading));
      expect(
        ComeBacksView.reading.toString(),
        'ComeBacksView(0, next: null, [])',
      );
    });
  });
}
