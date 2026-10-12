import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/application/use_cases/join_tournee.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/results.dart';

void main() {
  final preview = JoinPreview(
    code: firstCode,
    tourneeId: tourneeId,
    number: number49,
    centre: csVillefranche,
    campaign: campaign2026,
  );
  final pending49 = TourneeSummary(
    id: tourneeId,
    number: number49,
    centre: csVillefranche,
    campaign: campaign2026,
    status: MemberStatus.pending,
  );
  late FakeTourneeDirectory directory;
  late FakeMemberAccount account;
  late FakeMyTourneesStore store;

  setUp(() {
    directory = FakeTourneeDirectory()..previews[firstCode] = preview;
    account = FakeMemberAccount(signedInMember: julieId);
    store = FakeMyTourneesStore(MyTournees.none.remember(tournee12));
  });

  group('PreviewJoin', () {
    test('should show the tournée of the code', () async {
      expect(valueOf(await PreviewJoin(directory)(firstCode)), preview);
      expect(directory.previewed, [firstCode]);
    });

    test('should fail when no tournée has the code', () async {
      expect(
        failureOf(await PreviewJoin(directory)(codeOf('234567'))),
        JoinFailure.unknownCode,
      );
    });

    test('should fail offline', () async {
      directory.offline = true;

      expect(
        failureOf(await PreviewJoin(directory)(firstCode)),
        JoinFailure.noNetwork,
      );
    });
  });

  group('RequestToJoin', () {
    RequestToJoin requestToJoin() =>
        RequestToJoin(directory, account, store, FakeClock(julieAskedAt));

    test('should send Julie\'s pending request with the time', () async {
      await requestToJoin()(preview, nameOf('Julie'));

      expect(directory.sent, [(preview, julie)]);
    });

    test('should keep the tournée as a request after the others', () async {
      final sent = await requestToJoin()(preview, nameOf('Julie'));

      expect(valueOf(sent), pending49);
      expect(store.saves, [
        MyTournees.none.remember(tournee12).remember(pending49),
      ]);
    });

    test('should sign in first when the phone has no account yet', () async {
      account = FakeMemberAccount(nextMember: julieId);

      await requestToJoin()(preview, nameOf('Julie'));

      expect(account.signInCalls, 1);
      expect(directory.sent.single.$2.id, julieId);
    });

    test('should send nothing when the sign-in finds no network', () async {
      account = FakeMemberAccount();

      final sent = await requestToJoin()(preview, nameOf('Julie'));

      expect(failureOf(sent), RequestToJoinFailure.noNetwork);
      expect(directory.sent, isEmpty);
      expect(store.saves, isEmpty);
    });

    test(
      'should send nothing when the tournée is already one of the member\'s',
      () async {
        store = FakeMyTourneesStore(MyTournees.none.remember(pending49));

        final sent = await requestToJoin()(preview, nameOf('Julie'));

        expect(failureOf(sent), RequestToJoinFailure.alreadyJoined);
        expect(account.signInCalls, 0);
        expect(directory.sent, isEmpty);
        expect(store.saves, isEmpty);
      },
    );
  });

  group('CancelJoinRequest', () {
    setUp(() {
      store = FakeMyTourneesStore(
        MyTournees.none.remember(tournee12).remember(pending49),
      );
    });

    test('should withdraw the request and forget it on the phone', () async {
      await CancelJoinRequest(directory, account, store)(tourneeId);

      expect(directory.cancelled, [(tourneeId, julieId)]);
      expect(store.saves, [MyTournees.none.remember(tournee12)]);
    });

    test('should only forget it when the phone never signed in', () async {
      account = FakeMemberAccount();

      await CancelJoinRequest(directory, account, store)(TourneeId('t49'));

      expect(directory.cancelled, isEmpty);
      expect(store.saves, [MyTournees.none.remember(tournee12)]);
    });
  });
}
