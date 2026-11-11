import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';

import '../../domain/round/round_fixtures.dart';

import '../../support/street_fixtures.dart';

void main() {
  group('LastChange.of', () {
    // Local times: the screen shows the phone's time, whatever the zone the
    // tests run in.
    final now = DateTime(2026, 10, 4, 9, 30);

    test('should be today when the change was made today', () {
      final at = DateTime(2026, 10, 4, 0, 0);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedToday(at));
    });

    test('should be earlier when the change was made the day before', () {
      final at = DateTime(2026, 10, 3, 23, 59);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedEarlier(at));
    });

    test('should be earlier when the change was made the same day of '
        'another month', () {
      final at = DateTime(2026, 9, 4, 9, 30);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedEarlier(at));
    });

    test('should be earlier when the change was made the same day of '
        'another year', () {
      final at = DateTime(2025, 10, 4, 9, 30);

      expect(LastChange.of(at.toUtc(), now: now.toUtc()), ChangedEarlier(at));
    });

    test('should give the time in the phone time zone', () {
      final change = LastChange.of(twoPm, now: twoPm);

      expect(change.at, twoPm.toLocal());
      expect(change.at.isUtc, isFalse);
    });

    test('should be equal by kind and time', () {
      final at = DateTime(2026, 10, 4, 14, 2);

      expect(ChangedToday(at), ChangedToday(DateTime(2026, 10, 4, 14, 2)));
      expect(ChangedToday(at).hashCode, ChangedToday(at).hashCode);
      expect(ChangedToday(at), isNot(ChangedEarlier(at)));
      expect(ChangedToday(at), isNot(ChangedToday(DateTime(2026, 10, 4, 14))));
      expect(ChangedEarlier(at).hashCode, ChangedEarlier(at).hashCode);
      expect(ChangedEarlier(at), isNot(ChangedToday(at)));
      expect(
        ChangedToday(at, by: const ChangedByMe()),
        isNot(ChangedToday(at)),
      );
      expect(
        ChangedEarlier(at, by: const ChangedByMember('Léa')),
        ChangedEarlier(at, by: const ChangedByMember('Léa')),
      );
      expect(ChangedToday(at).toString(), 'ChangedToday($at, null)');
      expect(ChangedEarlier(at).toString(), 'ChangedEarlier($at, null)');
    });

    test('should keep who made the change', () {
      final change = LastChange.of(
        twoPm,
        now: twoPm,
        by: const ChangedByMember('Léa'),
      );

      expect(change.by, const ChangedByMember('Léa'));
    });
  });

  group('ChangeAuthor', () {
    test('should be equal by kind and name', () {
      // Built at run time: a `const` would be built by the compiler, so
      // the constructor lines would never count as covered.
      final name = 'Léa'.trim();

      // ignore: prefer_const_constructors
      expect(ChangedByMe(), const ChangedByMe());
      // ignore: prefer_const_constructors
      expect(ChangedByMe().hashCode, const ChangedByMe().hashCode);
      expect(ChangedByMember(name), const ChangedByMember('Léa'));
      expect(
        ChangedByMember(name).hashCode,
        const ChangedByMember('Léa').hashCode,
      );
      expect(ChangedByMember(name), isNot(const ChangedByMember('Paul')));
      expect(const ChangedByMe(), isNot(ChangedByMember(name)));
    });

    test('should name itself', () {
      expect('${const ChangedByMe()}', 'ChangedByMe');
      expect('${const ChangedByMember('Léa')}', 'ChangedByMember(Léa)');
    });
  });

  group('HouseSheetState', () {
    test('should tell loading and gone apart', () {
      // Built at run time (not `const`), so coverage sees the constructors.
      // ignore: prefer_const_constructors
      final HouseSheetState loading = HouseSheetLoading();
      // ignore: prefer_const_constructors
      final HouseSheetState gone = HouseSheetGone();

      expect(loading, isNot(isA<HouseSheetGone>()));
      expect(gone, isNot(isA<HouseSheetLoading>()));
    });
  });

  group('SheetSubject', () {
    test('should tell a house, a building and a door apart', () {
      // Built at run time (not `const`), so coverage sees the constructors.
      // ignore: prefer_const_constructors
      final SheetSubject house = HouseSubject();
      // ignore: prefer_const_constructors
      final SheetSubject building = BuildingSubject();
      // ignore: prefer_const_constructors
      final SheetSubject door = DoorSubject(staircase: null);

      expect(house, isNot(isA<BuildingSubject>()));
      expect(building, isNot(isA<DoorSubject>()));
      expect(door, isNot(isA<HouseSubject>()));
    });

    test('should be the same door when the staircase is the same', () {
      expect(DoorSubject(staircase: escA), DoorSubject(staircase: escA));
      expect(
        DoorSubject(staircase: escA).hashCode,
        DoorSubject(staircase: escA).hashCode,
      );
      expect(DoorSubject(staircase: escA), isNot(DoorSubject(staircase: escB)));
      expect(
        DoorSubject(staircase: escA),
        isNot(const DoorSubject(staircase: null)),
      );
    });

    test('should name the staircase when printed', () {
      expect(
        DoorSubject(staircase: escA).toString(),
        'DoorSubject(StaircaseName(A))',
      );
    });

    HouseSheetShown withStatus(
      VisitStatus? status, {
      int tries = 0,
      int calendars = 0,
      bool roundOn = false,
    }) => HouseSheetShown(
      streetName: 'Rue des Lilas',
      number: n('5'),
      status: status,
      comeBack: false,
      comeBackTime: ComeBackTime.of(null, today: day('2026-11-02')),
      lastChange: null,
      tries: tries,
      calendars: calendars,
      roundOn: roundOn,
    );

    for (final (status, roundOn, offers) in [
      (VisitStatus.done, true, true),
      (VisitStatus.done, false, false),
      (VisitStatus.refused, true, false),
      (VisitStatus.toDo, true, false),
      (VisitStatus.nobodyHome, true, false),
      (VisitStatus.comeBack, true, false),
      (null, true, false),
    ]) {
      test('should ${offers ? '' : 'not '}offer « + Ajouter un don » when the '
          'status is $status and roundOn is $roundOn', () {
        expect(withStatus(status, roundOn: roundOn).offersDonation, offers);
      });
    }

    test('should know no tournée by default', () {
      expect(withStatus(VisitStatus.done).roundOn, isFalse);
    });

    test('should have no tries by default', () {
      expect(withStatus(VisitStatus.toDo).tries, 0);
    });

    for (final (status, tries, offers) in [
      (VisitStatus.toDo, 1, false),
      (VisitStatus.done, 1, false),
      (VisitStatus.nobodyHome, 1, true),
      (VisitStatus.nobodyHome, 0, false),
      (VisitStatus.comeBack, 1, true),
      (VisitStatus.comeBack, 0, false),
      (VisitStatus.comeBack, 3, true),
      (null, 1, false),
    ]) {
      test('should ${offers ? '' : 'not '}offer « De nouveau personne » '
          'when the status is $status with $tries tries', () {
        expect(withStatus(status, tries: tries).offersNobodyHomeAgain, offers);
      });
    }

    for (final (tries, shows) in [(0, false), (1, true), (2, true)]) {
      test('should ${shows ? '' : 'not '}show the tries when $tries are '
          'counted', () {
        expect(
          withStatus(VisitStatus.nobodyHome, tries: tries).showsTries,
          shows,
        );
      });
    }

    test('should have no calendars by default', () {
      expect(withStatus(VisitStatus.toDo).calendars, 0);
    });

    for (final (status, shows) in [
      (VisitStatus.done, true),
      (VisitStatus.refused, false),
      (VisitStatus.toDo, false),
      (VisitStatus.nobodyHome, false),
      (VisitStatus.comeBack, false),
      (null, false),
    ]) {
      test('should ${shows ? '' : 'not '}show the calendars when the status '
          'is $status', () {
        expect(withStatus(status, calendars: 1).showsCalendars, shows);
      });
    }

    for (final (calendars, removes) in [(1, false), (2, true), (3, true)]) {
      test('should ${removes ? '' : 'not '}let « − » take a calendar away '
          'at $calendars', () {
        expect(
          withStatus(VisitStatus.done, calendars: calendars).canRemoveCalendar,
          removes,
        );
      });
    }

    test('should be about a house by default', () {
      final state = HouseSheetShown(
        streetName: 'Rue des Lilas',
        number: n('5'),
        status: VisitStatus.toDo,
        comeBack: false,
        comeBackTime: ComeBackTime.of(null, today: day('2026-11-02')),
        lastChange: null,
      );

      expect(state.subject, isA<HouseSubject>());
    });
  });

  group('StoredStatus', () {
    final marked = HouseMarked(
      streetId: StreetId('lilas'),
      before: House(number: n('7')),
      stamp: leaAtTwo,
      status: VisitStatus.nobodyHome,
    );
    final stored = StoredStatus(
      status: VisitStatus.nobodyHome,
      tries: 3,
      change: marked,
    );

    test('should be equal by status, tries and change', () {
      expect(
        stored,
        StoredStatus(status: VisitStatus.nobodyHome, tries: 3, change: marked),
      );
      expect(
        stored.hashCode,
        StoredStatus(
          status: VisitStatus.nobodyHome,
          tries: 3,
          change: marked,
        ).hashCode,
      );
      expect(
        stored,
        isNot(StoredStatus(status: VisitStatus.done, tries: 3, change: marked)),
      );
      expect(
        stored,
        isNot(
          StoredStatus(
            status: VisitStatus.nobodyHome,
            tries: 2,
            change: marked,
          ),
        ),
      );
      expect(
        stored,
        isNot(
          StoredStatus(
            status: VisitStatus.nobodyHome,
            tries: 3,
            change: HouseMarked(
              streetId: StreetId('lilas'),
              before: House(number: n('9')),
              stamp: leaAtTwo,
              status: VisitStatus.nobodyHome,
            ),
          ),
        ),
      );
    });

    test('should name its status and tries when printed', () {
      expect(
        stored.toString(),
        startsWith('StoredStatus(VisitStatus.nobodyHome, 3, '),
      );
    });

    test('should have no don by default', () {
      expect(stored.donation, isNull);
    });

    group('with a don', () {
      final given = GivenDonation(index: 4, donation: cash(1000));
      final withDon = stored.withDonation(given);

      test('should keep the status, tries and change, with the don', () {
        expect(withDon.status, VisitStatus.nobodyHome);
        expect(withDon.tries, 3);
        expect(withDon.change, marked);
        expect(withDon.donation, given);
      });

      test('should be equal by its don too', () {
        expect(withDon, stored.withDonation(given));
        expect(withDon.hashCode, stored.withDonation(given).hashCode);
        expect(withDon, isNot(stored));
        expect(
          withDon,
          isNot(
            stored.withDonation(GivenDonation(index: 3, donation: cash(1000))),
          ),
        );
      });

      test('should name its don when printed', () {
        expect(
          withDon.toString(),
          endsWith(', GivenDonation(4, ${cash(1000)}))'),
        );
      });
    });
  });

  group('GivenDonation', () {
    final given = GivenDonation(index: 2, donation: cheque(2000));

    test('should be equal by place and don', () {
      expect(given, GivenDonation(index: 2, donation: cheque(2000)));
      expect(
        given.hashCode,
        GivenDonation(index: 2, donation: cheque(2000)).hashCode,
      );
      expect(given, isNot(GivenDonation(index: 1, donation: cheque(2000))));
      expect(given, isNot(GivenDonation(index: 2, donation: cash(2000))));
    });

    test('should name its place and don when printed', () {
      expect(given.toString(), 'GivenDonation(2, PaidDonation(cheque, 2000))');
    });

    final change = HouseCalendarsCounted(
      streetId: StreetId('rue-des-lilas'),
      before: House(number: n('9'), status: VisitStatus.done),
      stamp: leaAtTwo,
      calendars: calendars(2),
    );

    test('should differ when only one has a calendar', () {
      expect(
        GivenDonation(index: 2, donation: cheque(2000), calendar: change),
        isNot(given),
      );
      expect(
        GivenDonation(index: 2, donation: cheque(2000), calendar: change),
        GivenDonation(index: 2, donation: cheque(2000), calendar: change),
      );
    });

    test('should differ when only one says the calendar was refused', () {
      final refused = GivenDonation(
        index: 2,
        donation: cheque(2000),
        calendarRefused: true,
      );

      expect(refused, isNot(given));
      expect(
        refused.hashCode,
        GivenDonation(
          index: 2,
          donation: cheque(2000),
          calendarRefused: true,
        ).hashCode,
      );
      expect(
        refused.toString(),
        'GivenDonation(2, PaidDonation(cheque, 2000), calendar refused)',
      );
    });

    test('should name its calendar too when printed', () {
      expect(
        GivenDonation(
          index: 2,
          donation: cheque(2000),
          calendar: change,
        ).toString(),
        'GivenDonation(2, PaidDonation(cheque, 2000), $change)',
      );
    });
  });
}
