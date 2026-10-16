import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notice.dart';
import 'package:tournee_calendriers/presentation/my_tournees/tournee_loss_notifier.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';

/// The 49 (open), the 12 and the pending 7.
MyTournees _manusPhone() => valueOf(
  MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7)
      .open(tournee49.id),
);

/// The 7, created by Léa, where Manu was accepted as « Manu ».
Tournee _tournee7Team() => valueOf(
  Tournee.create(
    id: tournee7.id,
    number: tournee7.number,
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
  late FakeMyTourneesStore store;
  late FakeTourneeDirectory directory;
  late FakeMemberAccount account;
  late FakePhoneSettings settings;
  late FakeTourneeRepository tournees;

  /// The phone keeps [mine]; it signed in before unless [withAccount] says
  /// otherwise.
  ProviderContainer containerWith(
    MyTournees mine, {
    FakeMemberAccount? withAccount,
  }) {
    store = FakeMyTourneesStore(mine);
    directory = FakeTourneeDirectory();
    account = withAccount ?? FakeMemberAccount(signedInMember: manuId);
    // Renamed « Emmanuel » in Paramètres.
    settings = FakePhoneSettings(memberName: nameOf('Emmanuel'));
    tournees = FakeTourneeRepository([team(), _tournee7Team()]);
    final container = ProviderContainer(
      overrides: [
        myTourneesStoreProvider.overrideWithValue(store),
        tourneeDirectoryProvider.overrideWithValue(directory),
        memberAccountProvider.overrideWithValue(account),
        phoneSettingsProvider.overrideWithValue(settings),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        identityProvider.overrideWithValue(FakeIdentity(manuId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should follow each tournée the member is in, as the signed-in '
      'member, and not their requests', () {
    final container = containerWith(_manusPhone());

    container.read(tourneeLossProvider);

    expect(directory.memberships, [(tournee49, manuId), (tournee12, manuId)]);
  });

  test('should tell nothing while no tournée is lost', () {
    final container = containerWith(_manusPhone());

    expect(container.read(tourneeLossProvider), isNull);
  });

  test('should forget the open tournée the member was removed from, open '
      'none, and tell it', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    directory.lose(tournee49.id, TourneeLoss.removed);
    await pumpEventQueue();

    expect(
      container.read(tourneeLossProvider),
      TourneeLossNotice(
        tournee: tournee49.id,
        number: 49,
        loss: TourneeLoss.removed,
        wasOpen: true,
      ),
    );
    expect(store.saves.single.tournees, [tournee12, tournee7]);
    expect(store.saves.single.current, isNull);
    expect(directory.isFollowing(tournee49.id), isFalse);
  });

  test('should forget another tournée deleted, keep the open one, and tell '
      'it', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    directory.lose(tournee12.id, TourneeLoss.deleted);
    await pumpEventQueue();

    expect(
      container.read(tourneeLossProvider),
      TourneeLossNotice(
        tournee: tournee12.id,
        number: 12,
        loss: TourneeLoss.deleted,
        wasOpen: false,
      ),
    );
    expect(store.saves.single.tournees, [tournee49, tournee7]);
    expect(store.saves.single.current, tournee49);
  });

  test('should keep every tournée while offline: the server says '
      'nothing', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    await pumpEventQueue();

    expect(container.read(tourneeLossProvider), isNull);
    expect(store.saves, isEmpty);
    expect(directory.isFollowing(tournee49.id), isTrue);
  });

  test('should keep the tournée when its listener fails', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    directory.failMembership(tournee49.id);
    await pumpEventQueue();

    expect(container.read(tourneeLossProvider), isNull);
    expect(store.saves, isEmpty);
  });

  test('should tell nothing for a tournée the phone forgot meanwhile '
      '(left, deleted from this phone)', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);
    // Forgotten without a change heard yet: the loss still arrives.
    store.myTournees = _manusPhone().forget(tournee49.id);

    directory.lose(tournee49.id, TourneeLoss.removed);
    await pumpEventQueue();

    expect(container.read(tourneeLossProvider), isNull);
    expect(store.saves, isEmpty);
  });

  test('should follow a tournée the member is accepted in later', () async {
    final container = containerWith(MyTournees.none.remember(tournee7));
    container.read(tourneeLossProvider);
    expect(directory.memberships, isEmpty);

    await store.save(MyTournees.none.remember(tournee7.accepted()));

    expect(directory.memberships, [(tournee7.accepted(), manuId)]);
  });

  test('should follow a tournée once however often the list changes', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    await store.save(valueOf(_manusPhone().open(tournee12.id)));

    expect(directory.memberships, hasLength(2));
  });

  group('the member\'s name', () {
    test('should listen to the name the server holds in each tournée the '
        'member is in, and not in their requests', () {
      final container = containerWith(_manusPhone());

      container.read(tourneeLossProvider);

      expect(directory.ownNames, [
        (tournee49.id, manuId),
        (tournee12.id, manuId),
      ]);
    });

    test('should send the new name to a tournée once the request made '
        'before the rename is accepted', () async {
      final container = containerWith(MyTournees.none.remember(tournee7));
      container.read(tourneeLossProvider);
      await store.save(MyTournees.none.remember(tournee7.accepted()));

      directory.hearName(tournee7.id, nameOf('Manu'));
      await pumpEventQueue();

      final renamed = Member(
        id: manuId,
        name: nameOf('Emmanuel'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: leaId, at: leaAcceptedAt),
      );
      expect(
        tournees.saved.single.$2,
        MemberRenamed(tourneeId: tournee7.id, member: renamed),
      );
      expect(tournees[tournee7.id]!.memberOf(manuId), renamed);
      expect(container.read(tourneeLossProvider), isNull);
    });

    test('should send nothing while the server holds the phone\'s '
        'name', () async {
      final container = containerWith(_manusPhone());
      container.read(tourneeLossProvider);

      directory.hearName(tournee49.id, nameOf('Emmanuel'));
      await pumpEventQueue();

      expect(tournees.saved, isEmpty);
    });

    test('should send nothing when the listener of the name fails', () async {
      final container = containerWith(_manusPhone());
      container.read(tourneeLossProvider);

      directory.failOwnName(tournee49.id);
      await pumpEventQueue();

      expect(tournees.saved, isEmpty);
      expect(container.read(tourneeLossProvider), isNull);
      expect(directory.isHearingName(tournee49.id), isTrue);
    });

    test('should stop listening to the name in a tournée lost', () async {
      final container = containerWith(_manusPhone());
      container.read(tourneeLossProvider);

      directory.lose(tournee49.id, TourneeLoss.removed);
      await pumpEventQueue();

      expect(directory.isHearingName(tournee49.id), isFalse);
      expect(directory.isHearingName(tournee12.id), isTrue);
    });

    test('should listen to the name once a sign-in succeeds after '
        'launch', () async {
      final container = containerWith(
        _manusPhone(),
        withAccount: FakeMemberAccount(nextMember: manuId),
      );
      container.read(tourneeLossProvider);
      expect(directory.ownNames, isEmpty);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.ownNames, [
        (tournee49.id, manuId),
        (tournee12.id, manuId),
      ]);
      expect(directory.isHearingName(tournee49.id), isTrue);
    });

    test('should stop listening to the name when the app goes away', () {
      final container = containerWith(_manusPhone());
      container.read(tourneeLossProvider);

      container.dispose();

      expect(directory.isHearingName(tournee49.id), isFalse);
      expect(directory.isHearingName(tournee12.id), isFalse);
    });
  });

  group('on a phone that never signed in', () {
    ProviderContainer neverSignedIn() => containerWith(
      _manusPhone(),
      withAccount: FakeMemberAccount(nextMember: manuId),
    );

    test('should follow nothing before the sign-in', () {
      final container = neverSignedIn();

      container.read(tourneeLossProvider);

      expect(directory.memberships, isEmpty);
    });

    test('should follow the member\'s tournées once a sign-in succeeds '
        'after launch', () async {
      final container = neverSignedIn();
      container.read(tourneeLossProvider);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.memberships, [(tournee49, manuId), (tournee12, manuId)]);
      expect(directory.isFollowing(tournee49.id), isTrue);
      expect(directory.isFollowing(tournee12.id), isTrue);
      expect(directory.isFollowing(tournee7.id), isFalse);
    });

    test('should forget a tournée lost after the sign-in, and tell '
        'it', () async {
      final container = neverSignedIn();
      container.read(tourneeLossProvider);
      await account.signInIfNeeded();
      await pumpEventQueue();

      directory.lose(tournee12.id, TourneeLoss.deleted);
      await pumpEventQueue();

      expect(
        container.read(tourneeLossProvider),
        TourneeLossNotice(
          tournee: tournee12.id,
          number: 12,
          loss: TourneeLoss.deleted,
          wasOpen: false,
        ),
      );
      expect(store.saves.single.tournees, [tournee49, tournee7]);
    });

    test('should follow the tournées the phone keeps at the sign-in, not '
        'those of launch', () async {
      final container = neverSignedIn();
      container.read(tourneeLossProvider);
      // Forgotten on this phone before the sign-in, without a change
      // heard: only the list of now counts.
      store.myTournees = _manusPhone().forget(tournee12.id);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.memberships, [(tournee49, manuId)]);
    });

    test('should follow nothing while the sign-in fails', () async {
      final container = containerWith(
        _manusPhone(),
        withAccount: FakeMemberAccount(),
      );
      container.read(tourneeLossProvider);

      await account.signInIfNeeded();
      await pumpEventQueue();

      expect(directory.memberships, isEmpty);
    });

    test('should stop waiting for the sign-in when the app goes away', () {
      final container = neverSignedIn();
      container.read(tourneeLossProvider);

      container.dispose();

      expect(account.isWaitedFor, isFalse);
    });
  });

  test('should stop following when the app goes away', () {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);

    container.dispose();

    expect(directory.isFollowing(tournee49.id), isFalse);
    expect(directory.isFollowing(tournee12.id), isFalse);
  });

  test('should tell nothing once the app has gone away', () async {
    final container = containerWith(_manusPhone());
    container.read(tourneeLossProvider);
    // The app goes away while the phone forgets the tournée.
    store.changes.listen((_) => container.dispose());

    directory.lose(tournee49.id, TourneeLoss.removed);
    await pumpEventQueue();

    expect(store.saves.single.find(tournee49.id), isNull);
  });

  group('TourneeLossNotice', () {
    TourneeLossNotice notice({
      String tournee = 't49',
      int number = 49,
      TourneeLoss loss = TourneeLoss.removed,
      bool wasOpen = true,
    }) => TourneeLossNotice(
      tournee: TourneeId(tournee),
      number: number,
      loss: loss,
      wasOpen: wasOpen,
    );

    test('should compare notices field by field', () {
      expect(notice(), notice());
      expect(notice().hashCode, notice().hashCode);
      for (final other in [
        notice(tournee: 't50'),
        notice(number: 50),
        notice(loss: TourneeLoss.deleted),
        notice(wasOpen: false),
      ]) {
        expect(notice() == other, isFalse, reason: '$other');
      }
    });

    test('should name the tournée and the loss', () {
      expect('${notice()}', 'TourneeLossNotice(t49, 49, removed, open)');
      expect(
        '${notice(wasOpen: false)}',
        'TourneeLossNotice(t49, 49, removed, closed)',
      );
    });
  });
}
