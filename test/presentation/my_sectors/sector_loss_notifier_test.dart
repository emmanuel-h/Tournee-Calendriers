import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/sector_loss_notice.dart';
import 'package:tournee_calendriers/presentation/my_sectors/sector_loss_notifier.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_cache_reset.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MySectors _manusPhone() => valueOf(
  MySectors.none
      .remember(sector49)
      .remember(sector12)
      .remember(sector7)
      .open(sector49.id),
);

/// The 7, created by Léa, where Manu was accepted as « Manu ».
Sector _sector7Team() => valueOf(
  Sector.create(
    id: sector7.id,
    number: sector7.number,
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

void main() {
  late FakeMySectorsStore store;
  late FakeSectorDirectory directory;
  late FakeMemberAccount account;
  late FakePhoneSettings settings;
  late FakeSectorRepository sectors;

  /// The phone keeps [mine]; it signed in before unless [withAccount] says
  /// otherwise.
  ProviderContainer containerWith(
    MySectors mine, {
    FakeMemberAccount? withAccount,
  }) {
    store = FakeMySectorsStore(mine);
    directory = FakeSectorDirectory();
    account = withAccount ?? FakeMemberAccount(signedInMember: manuId);
    // Renamed « Emmanuel » in Paramètres.
    settings = FakePhoneSettings(memberName: nameOf('Emmanuel'));
    sectors = FakeSectorRepository([team(), _sector7Team()]);
    final container = ProviderContainer(
      overrides: [
        mySectorsStoreProvider.overrideWithValue(store),
        phoneCacheResetProvider.overrideWithValue(FakePhoneCacheReset()),
        sectorDirectoryProvider.overrideWithValue(directory),
        memberAccountProvider.overrideWithValue(account),
        phoneSettingsProvider.overrideWithValue(settings),
        sectorRepositoryProvider.overrideWithValue(sectors),
        identityProvider.overrideWithValue(FakeIdentity(manuId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should follow each tournée the member is in, as the signed-in '
      'member, and not their requests', () {
    final container = containerWith(_manusPhone());

    container.read(sectorLossProvider);

    expect(directory.memberships, [(sector49, manuId), (sector12, manuId)]);
  });

  test('should follow a tournée an admin visits, and forget it once they '
      'are no longer an admin', () async {
    final container = containerWith(
      valueOf(
        MySectors.none
            .remember(sector49)
            .remember(sector12Visited)
            .open(sector12Visited.id),
      ),
    );
    container.read(sectorLossProvider);

    directory.lose(sector12Visited.id, SectorLoss.adminRevoked);
    await pumpEventQueue();

    expect(directory.memberships.last, (sector12Visited, manuId));
    expect(
      container.read(sectorLossProvider),
      SectorLossNotice(
        sector: sector12Visited.id,
        number: 12,
        loss: SectorLoss.adminRevoked,
        wasOpen: true,
      ),
    );
    expect(store.mySectors.sectors, [sector49]);
    expect(store.mySectors.currentId, isNull);
  });

  test('should still forget a visited tournée once the admin is revoked '
      'after its listener failed', () async {
    // Revoked, the admin may no longer read the tournée: its listener
    // fails (permission-denied) before their own `admins/{uid}` listener
    // tells the revocation. The failure shows nothing; the revocation is
    // told as usual.
    final container = containerWith(
      valueOf(
        MySectors.none.remember(sector12Visited).open(sector12Visited.id),
      ),
    );
    container.read(sectorLossProvider);

    directory.failMembership(sector12Visited.id);
    await pumpEventQueue();
    expect(container.read(sectorLossProvider), isNull);
    directory.lose(sector12Visited.id, SectorLoss.adminRevoked);
    await pumpEventQueue();

    expect(
      container.read(sectorLossProvider),
      SectorLossNotice(
        sector: sector12Visited.id,
        number: 12,
        loss: SectorLoss.adminRevoked,
        wasOpen: true,
      ),
    );
    expect(store.mySectors.sectors, isEmpty);
  });

  test('should follow a visited tournée as a member once the admin has '
      'joined it', () async {
    final container = containerWith(MySectors.none.remember(sector12Visited));
    container.read(sectorLossProvider);

    await store.save(store.mySectors.remember(sector12Visited.accepted()));
    await pumpEventQueue();

    expect(directory.memberships, [
      (sector12Visited, manuId),
      (sector12, manuId),
    ]);
    // The visit is no longer followed: a revoked admin keeps a tournée
    // they are in.
    expect(directory.isFollowing(sector12.id), isTrue);
  });

  test('should tell nothing while no tournée is lost', () {
    final container = containerWith(_manusPhone());

    expect(container.read(sectorLossProvider), isNull);
  });

  test('should forget the open tournée the member was removed from, open '
      'none, and tell it', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);

    directory.lose(sector49.id, SectorLoss.removed);
    await pumpEventQueue();

    expect(
      container.read(sectorLossProvider),
      SectorLossNotice(
        sector: sector49.id,
        number: 49,
        loss: SectorLoss.removed,
        wasOpen: true,
      ),
    );
    expect(store.saves.single.sectors, [sector12, sector7]);
    expect(store.saves.single.current, isNull);
    expect(directory.isFollowing(sector49.id), isFalse);
  });

  test('should forget another tournée deleted, keep the open one, and tell '
      'it', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);

    directory.lose(sector12.id, SectorLoss.deleted);
    await pumpEventQueue();

    expect(
      container.read(sectorLossProvider),
      SectorLossNotice(
        sector: sector12.id,
        number: 12,
        loss: SectorLoss.deleted,
        wasOpen: false,
      ),
    );
    expect(store.saves.single.sectors, [sector49, sector7]);
    expect(store.saves.single.current, sector49);
  });

  test('should keep every tournée while offline: the server says '
      'nothing', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);

    await pumpEventQueue();

    expect(container.read(sectorLossProvider), isNull);
    expect(store.saves, isEmpty);
    expect(directory.isFollowing(sector49.id), isTrue);
  });

  test('should keep the tournée when its listener fails', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);

    directory.failMembership(sector49.id);
    await pumpEventQueue();

    expect(container.read(sectorLossProvider), isNull);
    expect(store.saves, isEmpty);
  });

  test('should tell nothing for a tournée the phone forgot meanwhile '
      '(left, deleted from this phone)', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);
    // Forgotten without a change heard yet: the loss still arrives.
    store.mySectors = _manusPhone().forget(sector49.id);

    directory.lose(sector49.id, SectorLoss.removed);
    await pumpEventQueue();

    expect(container.read(sectorLossProvider), isNull);
    expect(store.saves, isEmpty);
  });

  test('should follow a tournée the member is accepted in later', () async {
    final container = containerWith(MySectors.none.remember(sector7));
    container.read(sectorLossProvider);
    expect(directory.memberships, isEmpty);

    await store.save(MySectors.none.remember(sector7.accepted()));

    expect(directory.memberships, [(sector7.accepted(), manuId)]);
  });

  test('should follow a tournée once however often the list changes', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);

    await store.save(valueOf(_manusPhone().open(sector12.id)));

    expect(directory.memberships, hasLength(2));
  });

  group('the member\'s name', () {
    test('should listen to the name the server holds in each tournée the '
        'member is in, and not in their requests', () {
      final container = containerWith(_manusPhone());

      container.read(sectorLossProvider);

      expect(directory.ownNames, [
        (sector49.id, manuId),
        (sector12.id, manuId),
      ]);
    });

    test('should send the new name to a tournée once the request made '
        'before the rename is accepted', () async {
      final container = containerWith(MySectors.none.remember(sector7));
      container.read(sectorLossProvider);
      await store.save(MySectors.none.remember(sector7.accepted()));

      directory.hearName(sector7.id, nameOf('Manu'));
      await pumpEventQueue();

      final renamed = Member(
        id: manuId,
        name: nameOf('Emmanuel'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: leaId, at: leaAcceptedAt),
      );
      expect(
        sectors.saved.single.$2,
        MemberRenamed(sectorId: sector7.id, member: renamed),
      );
      expect(sectors[sector7.id]!.memberOf(manuId), renamed);
      expect(container.read(sectorLossProvider), isNull);
    });

    test('should send nothing while the server holds the phone\'s '
        'name', () async {
      final container = containerWith(_manusPhone());
      container.read(sectorLossProvider);

      directory.hearName(sector49.id, nameOf('Emmanuel'));
      await pumpEventQueue();

      expect(sectors.saved, isEmpty);
    });

    test('should send nothing when the listener of the name fails', () async {
      final container = containerWith(_manusPhone());
      container.read(sectorLossProvider);

      directory.failOwnName(sector49.id);
      await pumpEventQueue();

      expect(sectors.saved, isEmpty);
      expect(container.read(sectorLossProvider), isNull);
      expect(directory.isHearingName(sector49.id), isTrue);
    });

    test('should stop listening to the name in a tournée lost', () async {
      final container = containerWith(_manusPhone());
      container.read(sectorLossProvider);

      directory.lose(sector49.id, SectorLoss.removed);
      await pumpEventQueue();

      expect(directory.isHearingName(sector49.id), isFalse);
      expect(directory.isHearingName(sector12.id), isTrue);
    });

    test('should listen to the name once a sign-in succeeds after '
        'launch', () async {
      final container = containerWith(
        _manusPhone(),
        withAccount: FakeMemberAccount(nextMember: manuId),
      );
      container.read(sectorLossProvider);
      expect(directory.ownNames, isEmpty);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.ownNames, [
        (sector49.id, manuId),
        (sector12.id, manuId),
      ]);
      expect(directory.isHearingName(sector49.id), isTrue);
    });

    test('should stop listening to the name when the app goes away', () {
      final container = containerWith(_manusPhone());
      container.read(sectorLossProvider);

      container.dispose();

      expect(directory.isHearingName(sector49.id), isFalse);
      expect(directory.isHearingName(sector12.id), isFalse);
    });
  });

  group('on a phone that never signed in', () {
    ProviderContainer neverSignedIn() => containerWith(
      _manusPhone(),
      withAccount: FakeMemberAccount(nextMember: manuId),
    );

    test('should follow nothing before the sign-in', () {
      final container = neverSignedIn();

      container.read(sectorLossProvider);

      expect(directory.memberships, isEmpty);
    });

    test('should follow the member\'s tournées once a sign-in succeeds '
        'after launch', () async {
      final container = neverSignedIn();
      container.read(sectorLossProvider);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.memberships, [(sector49, manuId), (sector12, manuId)]);
      expect(directory.isFollowing(sector49.id), isTrue);
      expect(directory.isFollowing(sector12.id), isTrue);
      expect(directory.isFollowing(sector7.id), isFalse);
    });

    test('should forget a tournée lost after the sign-in, and tell '
        'it', () async {
      final container = neverSignedIn();
      container.read(sectorLossProvider);
      await account.signInIfNeeded();
      await pumpEventQueue();

      directory.lose(sector12.id, SectorLoss.deleted);
      await pumpEventQueue();

      expect(
        container.read(sectorLossProvider),
        SectorLossNotice(
          sector: sector12.id,
          number: 12,
          loss: SectorLoss.deleted,
          wasOpen: false,
        ),
      );
      expect(store.saves.single.sectors, [sector49, sector7]);
    });

    test('should follow the tournées the phone keeps at the sign-in, not '
        'those of launch', () async {
      final container = neverSignedIn();
      container.read(sectorLossProvider);
      // Forgotten on this phone before the sign-in, without a change
      // heard: only the list of now counts.
      store.mySectors = _manusPhone().forget(sector12.id);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.memberships, [(sector49, manuId)]);
    });

    test('should follow nothing while the sign-in fails', () async {
      final container = containerWith(
        _manusPhone(),
        withAccount: FakeMemberAccount(),
      );
      container.read(sectorLossProvider);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.memberships, isEmpty);
    });

    test('should stop waiting for the sign-in when the app goes away', () {
      final container = neverSignedIn();
      container.read(sectorLossProvider);

      container.dispose();

      expect(account.isWaitedFor, isFalse);
    });
  });

  test('should stop following when the app goes away', () {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);

    container.dispose();

    expect(directory.isFollowing(sector49.id), isFalse);
    expect(directory.isFollowing(sector12.id), isFalse);
  });

  test('should tell nothing once the app has gone away', () async {
    final container = containerWith(_manusPhone());
    container.read(sectorLossProvider);
    // The app goes away while the phone forgets the tournée.
    store.changes.listen((_) => container.dispose());

    directory.lose(sector49.id, SectorLoss.removed);
    await pumpEventQueue();

    expect(store.saves.single.find(sector49.id), isNull);
  });

  group('SectorLossNotice', () {
    SectorLossNotice notice({
      String sector = 't49',
      int number = 49,
      SectorLoss loss = SectorLoss.removed,
      bool wasOpen = true,
    }) => SectorLossNotice(
      sector: SectorId(sector),
      number: number,
      loss: loss,
      wasOpen: wasOpen,
    );

    test('should compare notices field by field', () {
      expect(notice(), notice());
      expect(notice().hashCode, notice().hashCode);
      for (final other in [
        notice(sector: 't50'),
        notice(number: 50),
        notice(loss: SectorLoss.deleted),
        notice(wasOpen: false),
      ]) {
        expect(notice() == other, isFalse, reason: '$other');
      }
    });

    test('should name the tournée and the loss', () {
      expect('${notice()}', 'SectorLossNotice(t49, 49, removed, open)');
      expect(
        '${notice(wasOpen: false)}',
        'SectorLossNotice(t49, 49, removed, closed)',
      );
    });
  });
}
