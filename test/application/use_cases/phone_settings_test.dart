import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

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

      expect(
        valueOf(changed),
        NameChanged(name: nameOf('Jean Paul'), kept: const []),
      );
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

    test('should remember the name in each of the member\'s tournées, '
        'requests included', () async {
      await changeName()('Emmanuel');

      expect(store.mySectors.sectors.map((s) => s.memberName), [
        nameOf('Emmanuel'),
        nameOf('Emmanuel'),
        nameOf('Emmanuel'),
      ]);
      expect(store.mySectors.currentId, sectorId);
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

    test('should keep the old name where the server says the new one is '
        'taken, and say so', () async {
      sectors.takenNames.add((sectorId, 'emmanuel'));

      final changed = await changeName()('Emmanuel');

      expect(
        valueOf(changed),
        NameChanged(
          name: nameOf('Emmanuel'),
          kept: [NameKept(sector: sector49, name: nameOf('Manu'))],
        ),
      );
      expect(settings.names, [nameOf('Emmanuel')]);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Manu'));
      expect(
        sectors[SectorId('t12')]!.memberOf(manuId)!.name,
        nameOf('Emmanuel'),
      );
      expect(store.mySectors.sectors.map((s) => s.memberName), [
        nameOf('Manu'),
        nameOf('Emmanuel'),
        nameOf('Emmanuel'),
      ]);
    });

    test('should keep the old name where a member of the phone\'s copy '
        'holds the new one', () async {
      // Julie waits in the 49; the 12 has no Julie.
      final changed = await changeName()('JULIE');

      expect(valueOf(changed).kept, [
        NameKept(sector: sector49, name: nameOf('Manu')),
      ]);
      expect(sectors.saved.map((saved) => saved.$2.sectorId), [
        SectorId('t12'),
      ]);
    });

    test('should keep the name the member went by in a tournée where the new '
        'one is taken', () async {
      store = FakeMySectorsStore(
        MySectors.none.remember(sector49.withMemberName(nameOf('Manu D.'))),
      );
      sectors.put(valueOf(team().rename(nameOf('Manu D.'), by: manuId)).$1);
      sectors.takenNames.add((sectorId, 'emmanuel'));

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed).kept, [
        NameKept(
          sector: sector49.withMemberName(nameOf('Manu D.')),
          name: nameOf('Manu D.'),
        ),
      ]);
      expect(store.saves, isEmpty);
    });

    test('should change nothing and tell when no tournée can be '
        'reached', () async {
      sectors.offline = true;

      final changed = await changeName()('Emmanuel');

      expect(failureOf(changed), RenameProblem.noNetwork);
      expect(settings.names, isEmpty);
      expect(store.saves, isEmpty);
      expect(sectors.saved, isEmpty);
    });

    test('should keep the name and leave a tournée out of reach to catch '
        'up later', () async {
      sectors.unreachable.add(SectorId('t12'));

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed).kept, isEmpty);
      expect(settings.names, [nameOf('Emmanuel')]);
      expect(sectors.saved.map((saved) => saved.$2.sectorId), [sectorId]);
      expect(
        store.mySectors.find(SectorId('t12'))!.memberName,
        nameOf('Emmanuel'),
      );
    });

    test('should keep the name offline when the member is active in no '
        'tournée', () async {
      store = FakeMySectorsStore(MySectors.none.remember(sector7));
      sectors.offline = true;

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed).name, nameOf('Emmanuel'));
      expect(settings.names, [nameOf('Emmanuel')]);
      expect(store.mySectors.find(sector7.id)!.memberName, nameOf('Emmanuel'));
    });

    test('should write nothing, offline too, where the member already has '
        'the name', () async {
      sectors.offline = true;

      final changed = await changeName()('Manu');

      expect(valueOf(changed).kept, isEmpty);
      expect(sectors.saved, isEmpty);
      expect(settings.names, [nameOf('Manu')]);
    });

    test(
      'should leave a tournée the admin only visits without a name',
      () async {
        store = FakeMySectorsStore(MySectors.none.remember(sector12Visited));

        await changeName()('Emmanuel');

        expect(store.mySectors.find(sector12Visited.id)!.memberName, isNull);
        expect(store.saves, isEmpty);
        expect(sectors.saved, isEmpty);
      },
    );

    test('should skip a tournée that cannot be read any more', () async {
      sectors.lose(SectorId('t12'));

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed).name, nameOf('Emmanuel'));
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

      expect(valueOf(changed).kept, isEmpty);
      expect(sectors.saved.map((saved) => saved.$2.sectorId), [sectorId]);
    });

    test('should skip a tournée whose server refuses the rename for another '
        'reason', () async {
      sectors.renameRefused = SectorWriteFailure.notAdmin;

      final changed = await changeName()('Emmanuel');

      expect(valueOf(changed).kept, isEmpty);
      expect(sectors.saved, isEmpty);
      expect(store.mySectors.find(sectorId)!.memberName, nameOf('Emmanuel'));
    });

    test('should rename in no tournée when the phone knows none', () async {
      store = FakeMySectorsStore();

      await changeName()('Emmanuel');

      expect(settings.names, [nameOf('Emmanuel')]);
      expect(sectors.saved, isEmpty);
    });

    test('should refuse and keep nothing when the name is blank', () async {
      final changed = await changeName()('   ');

      expect(failureOf(changed), const NameRefused(MemberNameFailure.blank));
      expect(settings.names, isEmpty);
      expect(settings.memberName, nameOf('Manu'));
      expect(sectors.saved, isEmpty);
    });

    test('should refuse and keep nothing when the name is too long', () async {
      final changed = await changeName()('a' * 31);

      expect(failureOf(changed), const NameRefused(MemberNameFailure.tooLong));
      expect(settings.names, isEmpty);
      expect(sectors.saved, isEmpty);
    });
  });

  group('values', () {
    final kept = NameKept(sector: sector49, name: nameOf('Manu'));

    test('should equal a refusal for the same reason only', () {
      const blank = NameRefused(MemberNameFailure.blank);

      expect(blank, const NameRefused(MemberNameFailure.blank));
      expect(
        blank.hashCode,
        const NameRefused(MemberNameFailure.blank).hashCode,
      );
      expect(blank == const NameRefused(MemberNameFailure.tooLong), isFalse);
      expect(blank.toString(), 'NameRefused(MemberNameFailure.blank)');
    });

    test('should equal a name kept in the same secteur under the same name '
        'only', () {
      expect(kept, NameKept(sector: sector49, name: nameOf('Manu')));
      expect(
        kept.hashCode,
        NameKept(sector: sector49, name: nameOf('Manu')).hashCode,
      );
      expect(kept == NameKept(sector: sector12, name: nameOf('Manu')), isFalse);
      expect(
        kept == NameKept(sector: sector49, name: nameOf('Manu D.')),
        isFalse,
      );
      expect(kept.toString(), 'NameKept(t49, Manu)');
    });

    test('should equal a change of the same name kept in the same secteurs '
        'only', () {
      final changed = NameChanged(name: nameOf('Paul'), kept: [kept]);

      expect(changed, NameChanged(name: nameOf('Paul'), kept: [kept]));
      expect(
        changed.hashCode,
        NameChanged(name: nameOf('Paul'), kept: [kept]).hashCode,
      );
      expect(
        changed == NameChanged(name: nameOf('Pierre'), kept: [kept]),
        isFalse,
      );
      expect(
        changed == NameChanged(name: nameOf('Paul'), kept: const []),
        isFalse,
      );
      expect(
        changed.toString(),
        'NameChanged(Paul, kept: [NameKept(t49, Manu)])',
      );
    });
  });

  group('ChangeSectorName', () {
    late FakeSectorRepository sectors;
    late FakeMySectorsStore store;

    setUp(() {
      sectors = FakeSectorRepository([team(), sector12Team()]);
      store = FakeMySectorsStore(manusSectors());
    });

    Future<Result<MemberName, RenameFailure>> rename(
      SectorId id,
      String text,
    ) => ChangeSectorName(sectors, FakeIdentity(manuId), store)(id, text);

    test('should give the member the name in that tournée only', () async {
      final renamed = await rename(sectorId, ' Manu   D. ');

      expect(valueOf(renamed), nameOf('Manu D.'));
      expect(sectors.saved.single.$2.sectorId, sectorId);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Manu D.'));
      expect(store.mySectors.find(sectorId)!.memberName, nameOf('Manu D.'));
      expect(store.mySectors.find(SectorId('t12'))!.memberName, isNull);
    });

    test('should refuse a text that cannot be a name', () async {
      expect(
        failureOf(await rename(sectorId, ' ')),
        const NameRefused(MemberNameFailure.blank),
      );
      expect(sectors.saved, isEmpty);
    });

    test('should tell when the name is taken there', () async {
      sectors.takenNames.add((sectorId, 'manu d'));

      expect(
        failureOf(await rename(sectorId, 'Manu D.')),
        RenameProblem.nameTaken,
      );
      expect(store.saves, isEmpty);
    });

    test('should tell when the server cannot be reached', () async {
      sectors.offline = true;

      expect(
        failureOf(await rename(sectorId, 'Manu D.')),
        RenameProblem.noNetwork,
      );
      expect(store.saves, isEmpty);
    });

    test('should tell when the member is no longer in the tournée', () async {
      sectors.lose(sectorId);

      expect(
        failureOf(await rename(sectorId, 'Manu D.')),
        RenameProblem.sectorGone,
      );
    });

    test('should tell when the tournée is not one the member is active '
        'in', () async {
      for (final id in [sector7.id, SectorId('t99')]) {
        expect(
          failureOf(await rename(id, 'Manu D.')),
          RenameProblem.sectorGone,
          reason: id.value,
        );
      }
      expect(sectors.saved, isEmpty);
    });

    test('should keep nothing more when the member already had the '
        'name', () async {
      store = FakeMySectorsStore(
        MySectors.none.remember(sector49.withMemberName(nameOf('Manu'))),
      );

      expect(valueOf(await rename(sectorId, 'Manu')), nameOf('Manu'));
      expect(store.saves, isEmpty);
      expect(sectors.saved, isEmpty);
    });
  });

  group('CatchUpMemberName', () {
    late FakePhoneSettings settings;
    late FakeSectorRepository sectors;
    late FakeMySectorsStore store;

    setUp(() {
      settings = FakePhoneSettings(memberName: nameOf('Emmanuel'));
      sectors = FakeSectorRepository([sector12Team()]);
      store = FakeMySectorsStore(manusSectors());
    });

    CatchUpMemberName catchUp() =>
        CatchUpMemberName(settings, sectors, FakeIdentity(manuId), store);

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
      expect(
        store.mySectors.find(SectorId('t12'))!.memberName,
        nameOf('Emmanuel'),
      );
    });

    test('should send the name the member goes by in that tournée rather '
        'than the prénom', () async {
      store = FakeMySectorsStore(
        MySectors.none.remember(sector12.withMemberName(nameOf('Manu D.'))),
      );

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(
        sectors[SectorId('t12')]!.memberOf(manuId)!.name,
        nameOf('Manu D.'),
      );
      expect(store.saves, isEmpty);
    });

    test('should keep the name the server holds where the phone\'s is '
        'taken', () async {
      sectors.takenNames.add((SectorId('t12'), 'emmanuel'));

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
      expect(store.mySectors.find(SectorId('t12'))!.memberName, nameOf('Manu'));
    });

    test('should keep nothing when the server cannot be reached', () async {
      sectors.offline = true;

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(store.saves, isEmpty);
    });

    test('should send nothing when the team sees the phone\'s name', () async {
      await catchUp()(SectorId('t12'), nameOf('Emmanuel'));

      expect(sectors.saved, isEmpty);
      expect(store.saves, isEmpty);
    });

    test('should send nothing when the phone keeps no name', () async {
      settings = FakePhoneSettings();

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
    });

    test('should send nothing to a tournée the member is not active in on '
        'the phone', () async {
      for (final id in [sector7.id, SectorId('t99')]) {
        await catchUp()(id, nameOf('Manu'));
      }
      store = FakeMySectorsStore(MySectors.none.remember(sector12Visited));
      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
    });

    test('should skip a tournée that cannot be read', () async {
      sectors.lose(SectorId('t12'));

      await catchUp()(SectorId('t12'), nameOf('Manu'));

      expect(sectors.saved, isEmpty);
      expect(store.saves, isEmpty);
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
      expect(store.saves, isEmpty);
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
