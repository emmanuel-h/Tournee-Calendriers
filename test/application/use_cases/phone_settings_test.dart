import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';

/// The 12, created by Léa, where Manu was accepted.
Sector sector12Team() => valueOf(
  Sector.create(
    id: SectorId('t12'),
    number: sector12.number,
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
MySectors manusSectors() => valueOf(
  MySectors.none
      .remember(sector49)
      .remember(sector12)
      .remember(sector7)
      .open(sector49.id),
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
    late FakeSectorRepository sectors;
    late FakeMySectorsStore store;

    setUp(() {
      settings = FakePhoneSettings(memberName: nameOf('Manu'));
      sectors = FakeSectorRepository([team(), sector12Team()]);
      store = FakeMySectorsStore(manusSectors());
    });

    ChangeMemberName changeName() =>
        ChangeMemberName(settings, sectors, FakeIdentity(manuId), store);

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
      expect(sectors.saved.map((saved) => saved.$2), [
        MemberRenamed(sectorId: sectorId, member: in49),
        MemberRenamed(sectorId: SectorId('t12'), member: in12),
      ]);
      expect(sectors[sectorId]!.memberOf(manuId), in49);
      expect(sectors[SectorId('t12')]!.memberOf(manuId), in12);
      expect(sectors[sectorId]!.memberOf(leaId), lea);
    });

    test(
      'should not ask for a tournée where the request still waits',
      () async {
        // The 7 is stored with Manu active, as if accepted since: the phone
        // does not know it yet, so it is left alone.
        sectors.put(
          valueOf(
            Sector.create(
              id: SectorId('t7'),
              number: sector7.number,
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

        expect(sectors.saved.map((saved) => saved.$2.sectorId), [
          sectorId,
          SectorId('t12'),
        ]);
      },
    );

    test('should skip a tournée that cannot be read any more', () async {
      sectors.lose(SectorId('t12'));

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed), nameOf('Emmanuel'));
      expect(sectors.saved.map((saved) => saved.$2.sectorId), [sectorId]);
    });

    test('should skip a tournée that refuses the rename', () async {
      // Manu was removed from the 12 by Léa while the phone still lists it.
      sectors.put(
        valueOf(
          Sector.create(
            id: SectorId('t12'),
            number: sector12.number,
            centre: csVillefranche,
            joinCode: codeOf('ABCDEF'),
            createdBy: leaId,
            createdAt: createdAt,
            currentCampaign: campaign2026,
            members: [sector12Team().memberOf(leaId)!],
          ),
        ),
      );

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed), nameOf('Emmanuel'));
      expect(sectors.saved.map((saved) => saved.$2.sectorId), [sectorId]);
    });

    test('should rename in no tournée when the phone knows none', () async {
      store = FakeMySectorsStore();

      await changeName()('Emmanuel');

      expect(settings.names, [nameOf('Emmanuel')]);
      expect(sectors.saved, isEmpty);
    });

    test('should refuse and keep nothing when the name is blank', () async {
      final changed = await changeName()('   ');

      expect(failureOf(changed), MemberNameFailure.blank);
      expect(settings.names, isEmpty);
      expect(settings.memberName, nameOf('Manu'));
      expect(sectors.saved, isEmpty);
    });

    test('should refuse and keep nothing when the name is too long', () async {
      final changed = await changeName()('a' * 31);

      expect(failureOf(changed), MemberNameFailure.tooLong);
      expect(settings.names, isEmpty);
      expect(sectors.saved, isEmpty);
    });
  });

  group('CatchUpMemberName', () {
    late FakePhoneSettings settings;
    late FakeSectorRepository sectors;

    setUp(() {
      settings = FakePhoneSettings(memberName: nameOf('Emmanuel'));
      sectors = FakeSectorRepository([sector12Team()]);
    });

    CatchUpMemberName catchUp() =>
        CatchUpMemberName(settings, sectors, FakeIdentity(manuId));

    test('should send the phone\'s name to a tournée where the team sees '
        'another one', () async {
      // Renamed while the request to the 12 waited: the 12 still has
      // « Manu ».
      await catchUp()(SectorId('t12'), nameOf('Manu'));

      final in12 = Member(
        id: manuId,
        name: nameOf('Emmanuel'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: leaId, at: leaAcceptedAt),
      );
      expect(
        sectors.saved.single.$2,
        MemberRenamed(sectorId: SectorId('t12'), member: in12),
      );
      expect(sectors[SectorId('t12')]!.memberOf(manuId), in12);
    });

    test('should send nothing when the team sees the phone\'s name', () async {
      await catchUp()(SectorId('t12'), nameOf('Emmanuel'));

      expect(sectors.saved, isEmpty);
    });

    test('should send nothing when the phone keeps no name', () async {
      settings = FakePhoneSettings();

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
    });

    test('should skip a tournée that cannot be read', () async {
      sectors.lose(SectorId('t12'));

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
    });

    test('should skip a tournée that refuses the rename', () async {
      // Removed from the 12 meanwhile.
      sectors.put(
        valueOf(
          Sector.create(
            id: SectorId('t12'),
            number: sector12.number,
            centre: csVillefranche,
            joinCode: codeOf('ABCDEF'),
            createdBy: leaId,
            createdAt: createdAt,
            currentCampaign: campaign2026,
            members: [sector12Team().memberOf(leaId)!],
          ),
        ),
      );

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
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
