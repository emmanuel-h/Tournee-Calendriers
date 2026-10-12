import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/join/join_tournee_notifier.dart';
import 'package:tournee_calendriers/presentation/join/join_tournee_state.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_directory.dart';

/// Lets every pending future run.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final preview49 = JoinPreview(
    code: firstCode,
    tourneeId: tourneeId,
    number: number49,
    centre: csVillefranche,
    campaign: campaign2026,
  );
  const found49 = TourneeFound(
    number: 49,
    centre: 'CS Villefranche',
    campaign: 2026,
  );

  late FakeMemberAccount account;
  late FakeTourneeDirectory directory;
  late FakeMyTourneesStore store;
  late ProviderContainer container;

  /// Opens « Rejoindre une tournée » on Julie's phone; [name] is the name
  /// kept.
  Future<void> open({MemberName? name}) async {
    container = ProviderContainer(
      overrides: [
        memberAccountProvider.overrideWithValue(account),
        tourneeDirectoryProvider.overrideWithValue(directory),
        myTourneesStoreProvider.overrideWithValue(store),
        phoneSettingsProvider.overrideWithValue(
          FakePhoneSettings(memberName: name),
        ),
        clockProvider.overrideWithValue(FakeClock(julieAskedAt)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(joinTourneeProvider, (_, _) {});
    await _settle();
  }

  JoinTourneeState state() => container.read(joinTourneeProvider);
  JoinTourneeNotifier join() => container.read(joinTourneeProvider.notifier);

  /// Types K7P then 2QX, the code of the 49.
  Future<void> typeCode() async {
    join().typeFirstHalf('k7p');
    join().typeSecondHalf('2qx');
    await _settle();
  }

  setUp(() {
    account = FakeMemberAccount(signedInMember: julieId);
    directory = FakeTourneeDirectory()..previews[firstCode] = preview49;
    store = FakeMyTourneesStore();
  });

  group('the code', () {
    setUp(() => open(name: nameOf('Julie')));

    test('should start empty, with nothing to show', () {
      expect(state().first, '');
      expect(state().second, '');
      expect(state().invalidCharacter, isFalse);
      expect(state().scanRefused, isFalse);
      expect(state().lookup, const NoLookup());
      expect(state().run, const JoinIdle());
      expect(state().signedIn, isTrue);
      expect(state().hasName, isTrue);
      expect(state().canRequest, isFalse);
    });

    test('should ask nothing while the code is incomplete', () async {
      join().typeFirstHalf('k7p');
      join().typeSecondHalf('2q');
      await _settle();

      expect(state().first, 'K7P');
      expect(state().second, '2Q');
      expect(state().lookup, const NoLookup());
      expect(directory.previewed, isEmpty);
    });

    test('should show the tournée of a complete code', () async {
      await typeCode();

      expect(directory.previewed, [firstCode]);
      expect(state().lookup, found49);
      expect(state().canRequest, isTrue);
    });

    test('should be looking it up while the server answers', () async {
      directory.previewGates.add(Completer<void>());

      await typeCode();

      expect(state().lookup, const LookingUp());
      expect(state().canRequest, isFalse);
    });

    test(
      'should fill both boxes with a whole code typed in the first',
      () async {
        join().typeFirstHalf(' k7p-2qx ');
        await _settle();

        expect(state().first, 'K7P');
        expect(state().second, '2QX');
        expect(state().lookup, found49);
      },
    );

    test('should drop what is typed past the second box', () async {
      join().typeFirstHalf('K7P');
      join().typeSecondHalf('2QXZ');

      expect(state().second, '2QX');
    });

    test('should keep three characters in the first box', () {
      join().typeFirstHalf('K7P');

      expect(state().first, 'K7P');
      expect(state().second, '');
    });

    test('should say a character no code has is typed', () async {
      join().typeFirstHalf('K0P');
      await _settle();

      expect(state().invalidCharacter, isTrue);
      expect(state().lookup, const NoLookup());
      expect(directory.previewed, isEmpty);
    });

    test('should stop saying it once the character is gone', () {
      join().typeFirstHalf('K0P');

      join().typeFirstHalf('K7P');

      expect(state().invalidCharacter, isFalse);
    });

    test('should say no tournée has an unknown code', () async {
      join().typeFirstHalf('234567');
      await _settle();

      expect(state().lookup, const CodeUnknown());
      expect(state().canRequest, isFalse);
    });

    test('should forget the tournée shown when the code changes', () async {
      await typeCode();

      join().typeSecondHalf('2Q');

      expect(state().lookup, const NoLookup());
      expect(state().canRequest, isFalse);
    });

    test('should not ask again when the same code is typed again', () async {
      await typeCode();

      join().typeSecondHalf('2qx');
      await _settle();

      expect(directory.previewed, [firstCode]);
      expect(state().lookup, found49);
    });

    test('should ignore a late answer about an older code', () async {
      final slow = Completer<void>();
      directory.previewGates.add(slow);
      await typeCode();

      join().typeSecondHalf('2QY');
      await _settle();
      slow.complete();
      await _settle();

      expect(state().lookup, const CodeUnknown());
    });
  });

  group('offline', () {
    test(
      'should say offline and show the tournée after « Réessayer »',
      () async {
        directory.offline = true;
        await open(name: nameOf('Julie'));
        await typeCode();
        expect(state().lookup, const LookupOffline());

        directory.offline = false;
        await join().retryLookup();

        expect(state().lookup, found49);
        expect(directory.previewed, [firstCode, firstCode]);
      },
    );

    test('should not ask again on « Réessayer » when not offline', () async {
      await open(name: nameOf('Julie'));
      await typeCode();

      await join().retryLookup();

      expect(directory.previewed, [firstCode]);
    });

    test('should look the code up once the phone gets its account, after an '
        'offline first start', () async {
      account = FakeMemberAccount();
      await open(name: nameOf('Julie'));
      await typeCode();
      expect(state().signedIn, isFalse);
      expect(state().lookup, const NoLookup());
      expect(directory.previewed, isEmpty);

      account.nextMember = julieId;
      await container.read(accountProvider.notifier).retry();
      await _settle();

      expect(state().signedIn, isTrue);
      expect(state().lookup, found49);

      await join().request();

      expect(state().run, JoinSent(tourneeId));
    });

    test('should not look up an incomplete code once signed in', () async {
      account = FakeMemberAccount();
      await open(name: nameOf('Julie'));
      join().typeFirstHalf('K7P');

      account.nextMember = julieId;
      await container.read(accountProvider.notifier).retry();
      await _settle();

      expect(directory.previewed, isEmpty);
    });
  });

  group('scanning', () {
    setUp(() => open(name: nameOf('Julie')));

    test('should fill the boxes and show the tournée of a QR code', () async {
      join().scanned('K7P2QX');
      await _settle();

      expect(state().first, 'K7P');
      expect(state().second, '2QX');
      expect(state().lookup, found49);
    });

    test('should refuse a QR code that is not a tournée\'s', () {
      join().typeFirstHalf('K7P');

      join().scanned('https://example.org');

      expect(state().scanRefused, isTrue);
      expect(state().first, 'K7P');
    });

    test('should stop refusing once a code is typed', () {
      join().scanned('https://example.org');

      join().typeFirstHalf('K7P');

      expect(state().scanRefused, isFalse);
    });
  });

  group('« Demander à rejoindre »', () {
    test('should send the request and keep it pending on the phone', () async {
      await open(name: nameOf('Julie'));
      await typeCode();

      await join().request();

      expect(state().run, JoinSent(tourneeId));
      expect(state().canRequest, isFalse);
      expect(directory.sent, [(preview49, julie)]);
      expect(store.myTournees.find(tourneeId)?.status, MemberStatus.pending);
    });

    test('should be sending while it is sent', () async {
      account = FakeMemberAccount(signedInMember: julieId);
      await open(name: nameOf('Julie'));
      await typeCode();
      account.gate = Completer<void>();

      final sending = join().request();

      expect(state().run, const JoinSending());
      expect(state().canRequest, isFalse);
      account.gate.complete();
      await sending;
    });

    test('should say the tournée is already one of the member\'s', () async {
      store = FakeMyTourneesStore(
        MyTournees.none.remember(
          TourneeSummary(
            id: tourneeId,
            number: number49,
            centre: csVillefranche,
            campaign: campaign2026,
            status: MemberStatus.active,
          ),
        ),
      );
      await open(name: nameOf('Julie'));
      await typeCode();

      await join().request();

      expect(state().run, const JoinAlreadyJoined());
      expect(state().canRequest, isTrue);
      expect(directory.sent, isEmpty);
    });

    test('should say offline when the phone lost its account', () async {
      await open(name: nameOf('Julie'));
      await typeCode();
      account
        ..signedInMember = null
        ..nextMember = null;

      await join().request();

      expect(state().run, const JoinOffline());
      expect(state().canRequest, isTrue);
      expect(directory.sent, isEmpty);
    });

    test('should send nothing without a name kept', () async {
      await open();
      await typeCode();

      await join().request();

      expect(state().canRequest, isFalse);
      expect(directory.sent, isEmpty);
    });

    test('should send nothing before a tournée is shown', () async {
      await open(name: nameOf('Julie'));
      join().typeFirstHalf('234567');
      await _settle();

      await join().request();

      expect(directory.sent, isEmpty);
    });
  });

  group('values', () {
    test('should equal previews and sent requests with the same values', () {
      expect(found49, TourneeFound.of(preview49));
      expect(found49.hashCode, TourneeFound.of(preview49).hashCode);
      expect(
        found49,
        isNot(
          const TourneeFound(number: 49, centre: 'CS Anse', campaign: 2026),
        ),
      );
      expect(found49.toString(), 'TourneeFound(49, CS Villefranche, 2026)');
      expect(JoinSent(tourneeId), JoinSent(TourneeId('t49')));
      expect(JoinSent(tourneeId).hashCode, JoinSent(TourneeId('t49')).hashCode);
      expect(JoinSent(tourneeId), isNot(JoinSent(TourneeId('t12'))));
      expect(JoinSent(tourneeId).toString(), 'JoinSent(t49)');
    });
  });
}
