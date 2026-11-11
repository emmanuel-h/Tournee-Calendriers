import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_state.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';

/// The 49, the 12 and the pending 7; [open] is the one the app shows.
MySectors _manusPhone({SectorId? open}) {
  final mine = MySectors.none
      .remember(sector49)
      .remember(sector12)
      .remember(sector7);
  return open == null ? mine : valueOf(mine.open(open));
}

void main() {
  late FakeMySectorsStore store;
  late FakeSectorDirectory directory;
  late FakeSectorRepository sectors;

  ProviderContainer containerWith(MySectors mine) {
    store = FakeMySectorsStore(mine);
    directory = FakeSectorDirectory();
    // The 49 with Julie's request waiting; the 12 cannot be read.
    sectors = FakeSectorRepository([team()]);
    final container = ProviderContainer(
      overrides: [
        mySectorsStoreProvider.overrideWithValue(store),
        sectorDirectoryProvider.overrideWithValue(directory),
        sectorRepositoryProvider.overrideWithValue(sectors),
        memberAccountProvider.overrideWithValue(
          FakeMemberAccount(signedInMember: manuId),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should reopen the secteur the phone kept open at launch', () {
    final container = containerWith(_manusPhone(open: sector12.id));

    final state = container.read(mySectorsProvider);

    expect(state.current, sector12);
    expect(container.read(currentSectorProvider), sector12);
  });

  test('should list the secteurs in the phone order, each with its '
      'number, year, centre and status', () {
    final container = containerWith(_manusPhone(open: sector12.id));

    final rows = container.read(mySectorsProvider).rows;

    expect(rows.map((row) => row.id), [sector49.id, sector12.id, sector7.id]);
    expect(rows.map((row) => row.status), [
      SectorRowStatus.closed,
      SectorRowStatus.open,
      SectorRowStatus.pending,
    ]);
    expect(rows.first.number, 49);
    expect(rows.first.campaign, 2026);
    expect(rows.first.centre, 'CS Villefranche');
  });

  test('should show no secteur when the phone knows none', () {
    final container = containerWith(MySectors.none);

    final state = container.read(mySectorsProvider);

    expect(state.rows, isEmpty);
    expect(state.current, isNull);
    expect(container.read(currentSectorProvider), isNull);
  });

  test('should switch the observed secteur and keep it for the next '
      'launch', () async {
    final container = containerWith(_manusPhone(open: sector49.id));
    final observed = <Object?>[];
    container.listen(
      currentSectorProvider,
      (_, current) => observed.add(current),
    );

    await container.read(mySectorsProvider.notifier).open(sector12.id);

    expect(container.read(mySectorsProvider).current, sector12);
    // Riverpod tells the listeners of a derived provider once it is read
    // again (or at the next frame).
    expect(container.read(currentSectorProvider), sector12);
    expect(observed, [sector12]);
    expect(store.saves.single.currentId, sector12.id);
  });

  test('should keep the open secteur when the one asked cannot be '
      'opened', () async {
    final container = containerWith(_manusPhone(open: sector49.id));

    await container.read(mySectorsProvider.notifier).open(sector7.id);

    expect(container.read(mySectorsProvider).current, sector49);
    expect(store.saves, isEmpty);
  });

  test('should follow a list changed elsewhere', () async {
    final container = containerWith(_manusPhone(open: sector49.id));
    container.read(mySectorsProvider);

    await store.save(valueOf(_manusPhone().open(sector12.id)));

    expect(container.read(mySectorsProvider).current, sector12);
  });

  group('pending requests', () {
    test('should watch each pending request as the signed-in member', () {
      final container = containerWith(_manusPhone(open: sector49.id));

      container.read(mySectorsProvider);

      expect(directory.watched, [(sector7.id, manuId)]);
    });

    test('should make an accepted request one of the secteurs, not '
        'opened, and stop watching it', () async {
      final container = containerWith(_manusPhone(open: sector49.id));
      container.read(mySectorsProvider);

      directory.answer(sector7.id, MemberStatus.active);
      await pumpEventQueue();

      final rows = container.read(mySectorsProvider).rows;
      expect(rows.last.id, sector7.id);
      expect(rows.last.status, SectorRowStatus.closed);
      expect(container.read(mySectorsProvider).current, sector49);
      expect(directory.isWatching(sector7.id), isFalse);
    });

    test('should drop a refused request', () async {
      final container = containerWith(_manusPhone(open: sector49.id));
      container.read(mySectorsProvider);

      directory.answer(sector7.id, null);
      await pumpEventQueue();

      expect(container.read(mySectorsProvider).rows.map((row) => row.id), [
        sector49.id,
        sector12.id,
      ]);
    });

    test('should keep the request pending when its listener fails', () async {
      final container = containerWith(_manusPhone(open: sector49.id));
      container.read(mySectorsProvider);

      directory.fail(sector7.id);
      await pumpEventQueue();

      expect(
        container.read(mySectorsProvider).rows.last.status,
        SectorRowStatus.pending,
      );
      expect(store.saves, isEmpty);
    });

    test('should watch a request the phone sends later', () async {
      final container = containerWith(MySectors.none);
      container.read(mySectorsProvider);

      await store.save(MySectors.none.remember(sector7));

      expect(directory.watched, [(sector7.id, manuId)]);
      expect(directory.isWatching(sector7.id), isTrue);
    });

    test(
      'should watch a request once however often the list changes',
      () async {
        final container = containerWith(_manusPhone(open: sector49.id));
        container.read(mySectorsProvider);

        await store.save(valueOf(_manusPhone().open(sector12.id)));

        expect(directory.watched, hasLength(1));
      },
    );

    test('should stop watching when the app goes away', () {
      final container = containerWith(_manusPhone(open: sector49.id));
      container.read(mySectorsProvider);

      container.dispose();

      expect(directory.isWatching(sector7.id), isFalse);
    });
  });

  group('requests waiting in another secteur', () {
    int waitingIn(ProviderContainer container, SectorId id) => container
        .read(mySectorsProvider)
        .rows
        .firstWhere((row) => row.id == id)
        .waitingRequests;

    test('should count the requests waiting in a secteur not open', () async {
      final container = containerWith(_manusPhone(open: sector12.id));
      container.read(mySectorsProvider);
      await pumpEventQueue();

      expect(waitingIn(container, sector49.id), 1);
      expect(waitingIn(container, sector12.id), 0);
    });

    test('should follow only the secteurs not open, not the requests', () {
      final container = containerWith(_manusPhone(open: sector12.id));

      container.read(mySectorsProvider);

      expect(sectors.watched, [sector49.id]);
    });

    test('should follow the team live', () async {
      final container = containerWith(_manusPhone(open: sector12.id));
      container.read(mySectorsProvider);
      await pumpEventQueue();

      sectors.put(team(members: [manu, lea]));
      await pumpEventQueue();

      expect(waitingIn(container, sector49.id), 0);
    });

    test('should count none in a secteur it cannot read', () async {
      final container = containerWith(_manusPhone(open: sector49.id));
      container.read(mySectorsProvider);
      await pumpEventQueue();

      expect(waitingIn(container, sector12.id), 0);
    });

    test('should count none when the team cannot be followed', () async {
      final container = containerWith(_manusPhone(open: sector12.id));
      sectors.watchError = StateError('listener failed');
      container.read(mySectorsProvider);
      await pumpEventQueue();

      expect(waitingIn(container, sector49.id), 0);
    });

    test('should stop following a secteur once it is opened, and follow '
        'the one left', () async {
      final container = containerWith(_manusPhone(open: sector12.id));
      container.read(mySectorsProvider);
      await pumpEventQueue();

      await container.read(mySectorsProvider.notifier).open(sector49.id);
      await pumpEventQueue();

      expect(sectors.isWatching(sector49.id), isFalse);
      expect(sectors.isWatching(sector12.id), isTrue);
      expect(waitingIn(container, sector49.id), 0);
    });

    test('should stop following when the app goes away', () async {
      final container = containerWith(_manusPhone(open: sector12.id));
      container.read(mySectorsProvider);
      await pumpEventQueue();

      container.dispose();
      await pumpEventQueue();

      expect(sectors.isWatching(sector49.id), isFalse);
    });
  });
}
