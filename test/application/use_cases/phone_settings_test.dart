import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';

/// The 12, created by Léa, where Manu was accepted.
Tournee tournee12Team() => valueOf(
  Tournee.create(
    id: TourneeId('t12'),
    number: tournee12.number,
    centre: csVillefranche,
    joinCode: codeOf('ABCDEF'),
    createdBy: leaId,
    createdAt: createdAt,
    currentCampaign: campaign2026,
    members: [
      Member(
        id: leaId,
        name: nameOf('Léa'),
        requestedAt: createdAt,
        acceptance: ChangeStamp(by: leaId, at: createdAt),
      ),
      Member(
        id: manuId,
        name: nameOf('Manu'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: leaId, at: leaAcceptedAt),
      ),
    ],
  ),
);

/// Manu's phone: the 49 (open) and the 12, where he is active, and the 7,
/// where his request waits.
MyTournees manusTournees() => valueOf(
  MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7)
      .open(tournee49.id),
);

void main() {
  group('ReadPhoneSettings', () {
    test('should give the name and the theme kept on the phone', () {
      final settings = ReadPhoneSettings(
        FakePhoneSettings(memberName: nameOf('Manu'), theme: ThemeChoice.dark),
      )();

      expect(settings.name, nameOf('Manu'));
      expect(settings.theme, ThemeChoice.dark);
    });
  });

  group('ChangeMemberName', () {
    late FakePhoneSettings settings;
    late FakeTourneeRepository tournees;
    late FakeMyTourneesStore store;

    setUp(() {
      settings = FakePhoneSettings(memberName: nameOf('Manu'));
      tournees = FakeTourneeRepository([team(), tournee12Team()]);
      store = FakeMyTourneesStore(manusTournees());
    });

    ChangeMemberName changeName() =>
        ChangeMemberName(settings, tournees, FakeIdentity(manuId), store);

    test('should keep the name once cleaned', () async {
      final changed = await changeName()('  Jean   Paul ');

      expect(valueOf(changed).text, 'Jean Paul');
      expect(settings.names, [nameOf('Jean Paul')]);
    });

    test('should rename the member in each tournée they are active in '
        'when the name is kept', () async {
      await changeName()('Emmanuel');

      final in49 = Member(
        id: manuId,
        name: nameOf('Emmanuel'),
        requestedAt: createdAt,
        acceptance: ChangeStamp(by: manuId, at: createdAt),
      );
      final in12 = Member(
        id: manuId,
        name: nameOf('Emmanuel'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: leaId, at: leaAcceptedAt),
      );
      expect(tournees.saved.map((saved) => saved.$2), [
        MemberRenamed(tourneeId: tourneeId, member: in49),
        MemberRenamed(tourneeId: TourneeId('t12'), member: in12),
      ]);
      expect(tournees[tourneeId]!.memberOf(manuId), in49);
      expect(tournees[TourneeId('t12')]!.memberOf(manuId), in12);
      expect(tournees[tourneeId]!.memberOf(leaId), lea);
    });

    test(
      'should not ask for a tournée where the request still waits',
      () async {
        // The 7 is stored with Manu active, as if accepted since: the phone
        // does not know it yet, so it is left alone.
        tournees.put(
          valueOf(
            Tournee.create(
              id: TourneeId('t7'),
              number: tournee7.number,
              centre: csVillefranche,
              joinCode: codeOf('ABCDEF'),
              createdBy: manuId,
              createdAt: createdAt,
              currentCampaign: campaign2026,
              members: [manu],
            ),
          ),
        );

        await changeName()('Emmanuel');

        expect(tournees.saved.map((saved) => saved.$2.tourneeId), [
          tourneeId,
          TourneeId('t12'),
        ]);
      },
    );

    test('should skip a tournée that cannot be read any more', () async {
      tournees.lose(TourneeId('t12'));

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed), nameOf('Emmanuel'));
      expect(tournees.saved.map((saved) => saved.$2.tourneeId), [tourneeId]);
    });

    test('should skip a tournée that refuses the rename', () async {
      // Manu was removed from the 12 by Léa while the phone still lists it.
      tournees.put(
        valueOf(
          Tournee.create(
            id: TourneeId('t12'),
            number: tournee12.number,
            centre: csVillefranche,
            joinCode: codeOf('ABCDEF'),
            createdBy: leaId,
            createdAt: createdAt,
            currentCampaign: campaign2026,
            members: [tournee12Team().creator],
          ),
        ),
      );

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed), nameOf('Emmanuel'));
      expect(tournees.saved.map((saved) => saved.$2.tourneeId), [tourneeId]);
    });

    test('should rename in no tournée when the phone knows none', () async {
      store = FakeMyTourneesStore();

      await changeName()('Emmanuel');

      expect(settings.names, [nameOf('Emmanuel')]);
      expect(tournees.saved, isEmpty);
    });

    test('should refuse and keep nothing when the name is blank', () async {
      final changed = await changeName()('   ');

      expect(failureOf(changed), MemberNameFailure.blank);
      expect(settings.names, isEmpty);
      expect(settings.memberName, nameOf('Manu'));
      expect(tournees.saved, isEmpty);
    });

    test('should refuse and keep nothing when the name is too long', () async {
      final changed = await changeName()('a' * 31);

      expect(failureOf(changed), MemberNameFailure.tooLong);
      expect(settings.names, isEmpty);
      expect(tournees.saved, isEmpty);
    });
  });

  group('CatchUpMemberName', () {
    late FakePhoneSettings settings;
    late FakeTourneeRepository tournees;

    setUp(() {
      settings = FakePhoneSettings(memberName: nameOf('Emmanuel'));
      tournees = FakeTourneeRepository([tournee12Team()]);
    });

    CatchUpMemberName catchUp() =>
        CatchUpMemberName(settings, tournees, FakeIdentity(manuId));

    test('should send the phone\'s name to a tournée where the team sees '
        'another one', () async {
      // Renamed while the request to the 12 waited: the 12 still has
      // « Manu ».
      await catchUp()(TourneeId('t12'), nameOf('Manu'));

      final in12 = Member(
        id: manuId,
        name: nameOf('Emmanuel'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: leaId, at: leaAcceptedAt),
      );
      expect(
        tournees.saved.single.$2,
        MemberRenamed(tourneeId: TourneeId('t12'), member: in12),
      );
      expect(tournees[TourneeId('t12')]!.memberOf(manuId), in12);
    });

    test('should send nothing when the team sees the phone\'s name', () async {
      await catchUp()(TourneeId('t12'), nameOf('Emmanuel'));

      expect(tournees.saved, isEmpty);
    });

    test('should send nothing when the phone keeps no name', () async {
      settings = FakePhoneSettings();

      await catchUp()(TourneeId('t12'), nameOf('Manu'));

      expect(tournees.saved, isEmpty);
    });

    test('should skip a tournée that cannot be read', () async {
      tournees.lose(TourneeId('t12'));

      await catchUp()(TourneeId('t12'), nameOf('Manu'));

      expect(tournees.saved, isEmpty);
    });

    test('should skip a tournée that refuses the rename', () async {
      // Removed from the 12 meanwhile.
      tournees.put(
        valueOf(
          Tournee.create(
            id: TourneeId('t12'),
            number: tournee12.number,
            centre: csVillefranche,
            joinCode: codeOf('ABCDEF'),
            createdBy: leaId,
            createdAt: createdAt,
            currentCampaign: campaign2026,
            members: [tournee12Team().creator],
          ),
        ),
      );

      await catchUp()(TourneeId('t12'), nameOf('Manu'));

      expect(tournees.saved, isEmpty);
    });
  });

  group('ChooseTheme', () {
    test('should keep the theme chosen', () async {
      final settings = FakePhoneSettings();

      await ChooseTheme(settings)(ThemeChoice.light);

      expect(settings.themes, [ThemeChoice.light]);
    });
  });
}
