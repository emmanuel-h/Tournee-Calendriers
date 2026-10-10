// The tournées in Firestore, against an in-memory Firestore
// (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_tournee_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/tournee_document_mapper.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';

/// Tournée 49 of the CS Villefranche, just created by Manu.
final created = Tournee.createdBy(
  id: tourneeId,
  number: number49,
  centre: csVillefranche,
  campaign: campaign2026,
  joinCode: firstCode,
  creator: manuId,
  creatorName: nameOf('Manu'),
  at: createdAt,
);

/// The indexes of `2`, `3`, `4`, `5`, `6`, `7` in the code alphabet: the
/// code `234567` once drawn.
final draws234567 = [
  for (final character in '234567'.split(''))
    JoinCode.alphabet.indexOf(character),
];

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  late FakeFirebaseFirestore db;

  FirestoreTourneeRepository repository([Iterable<int> draws = const []]) =>
      FirestoreTourneeRepository(db, random: ScriptedRandom(draws));

  Future<Map<String, dynamic>?> stored(String path) async =>
      (await db.doc(path).get()).data();

  setUp(() => db = FakeFirebaseFirestore());

  group('add', () {
    test('should store the tournée with all that makes it findable', () async {
      final result = await repository().add(created);

      expect(valueOf(result), same(created));
      expect(await stored('tournees/t49'), tourneeToDocument(created));
      expect(
        await stored('tournees/t49/members/uid-manu'),
        memberToDocument(manu),
      );
      expect(
        await stored('tournees/t49/campaigns/2026'),
        firstCampaignDocument(created),
      );
      expect(await stored('joinCodes/K7P2QX'), joinCodeDocument(created));
      expect(await stored('tourneeKeys/villefranche_49'), {'tourneeId': 't49'});
      expect(await stored('rescueCentres/villefranche'), {
        'name': 'CS Villefranche',
      });
    });

    test('should refuse a number already taken in the same station', () async {
      // Written « CIS Villefranche » by someone else: the same station.
      await db.doc('tourneeKeys/villefranche_49').set({'tourneeId': 'other'});

      final result = await repository().add(created);

      expect(failureOf(result), AddTourneeFailure.alreadyExists);
      expect(await stored('tournees/t49'), isNull);
      expect(await stored('joinCodes/K7P2QX'), isNull);
    });

    test('should accept the same number in another station', () async {
      await db.doc('tourneeKeys/villefranche-sur-saone_49').set({
        'tourneeId': 'other',
      });

      expect(
        await repository().add(created),
        isA<Ok<Tournee, AddTourneeFailure>>(),
      );
    });

    test('should draw another code when the code is taken', () async {
      await db.doc('joinCodes/K7P2QX').set({'tourneeId': 'other'});

      final stored0 = valueOf(await repository(draws234567).add(created));

      expect(stored0.joinCode, codeOf('234567'));
      expect(stored0.members, created.members);
      expect((await stored('tournees/t49'))!['joinCode'], '234567');
      expect(await stored('joinCodes/234567'), joinCodeDocument(created));
      expect(await stored('joinCodes/K7P2QX'), {'tourneeId': 'other'});
    });

    test('should give up after drawing taken codes again and again', () async {
      await db.doc('joinCodes/K7P2QX').set({'tourneeId': 'other'});
      await db.doc('joinCodes/222222').set({'tourneeId': 'other'});
      final twos = List.filled(
        JoinCode.length * FirestoreTourneeRepository.maxCodeDraws,
        JoinCode.alphabet.indexOf('2'),
      );

      await expectLater(repository(twos).add(created), throwsStateError);
      expect(await stored('tournees/t49'), isNull);
    });

    test('should keep the name of a station already known', () async {
      await db.doc('rescueCentres/villefranche').set({
        'name': 'CIS Villefranche',
      });

      await repository().add(created);

      expect(await stored('rescueCentres/villefranche'), {
        'name': 'CIS Villefranche',
      });
    });

    test('should tell when the server cannot be reached', () async {
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('tourneeKeys/villefranche_49'))
          .thenThrow(firestoreError('unavailable'));

      final result = await repository().add(created);

      expect(failureOf(result), AddTourneeFailure.noNetwork);
    });

    test('should tell when the server does not answer in time', () async {
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('tourneeKeys/villefranche_49'))
          .thenThrow(firestoreError('deadline-exceeded'));

      final result = await repository().add(created);

      expect(failureOf(result), AddTourneeFailure.noNetwork);
    });

    test('should throw any other failure of the server', () async {
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('tourneeKeys/villefranche_49'))
          .thenThrow(firestoreError('permission-denied'));

      await expectLater(
        repository().add(created),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('find and watch', () {
    Future<void> storeTeam() async {
      await repository().add(created);
      for (final member in [lea, julie]) {
        await db
            .doc('tournees/t49/members/${member.id.value}')
            .set(memberToDocument(member));
      }
    }

    test('should find the tournée with every member', () async {
      await storeTeam();

      final found = (await repository().find(tourneeId))!;

      expect(found.number, number49);
      expect(found.joinCode, firstCode);
      expect(found.members, [manu, lea, julie]);
    });

    test('should find nothing when there is no such tournée', () async {
      expect(await repository().find(TourneeId('nope')), isNull);
    });

    test('should follow requests and acceptances live', () async {
      await repository().add(created);
      // The in-memory Firestore applies a transaction's writes a moment
      // after it completes.
      await pumpEventQueue();
      final seen = <List<String>>[];
      final subscription = repository()
          .watch(tourneeId)
          .listen(
            (tournee) => seen.add([
              for (final member in tournee!.members)
                '${member.id.value}:${member.status.name}',
            ]),
          );
      await pumpEventQueue();

      await db
          .doc('tournees/t49/members/uid-julie')
          .set(joinRequestDocument(julie, firstCode));
      await pumpEventQueue();
      final (accepted, change) = valueOf(
        team(members: [manu, julie])
            .accept(julieId, by: manuId, at: leaAcceptedAt),
      );
      await repository().save(accepted, change);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        ['uid-manu:active'],
        ['uid-manu:active', 'uid-julie:pending'],
        ['uid-manu:active', 'uid-julie:active'],
      ]);
    });

    test('should give null once the tournée is deleted', () async {
      await storeTeam();
      final seen = <Tournee?>[];
      final subscription = repository().watch(tourneeId).listen(seen.add);
      await pumpEventQueue();

      await repository().delete(valueOf(team().delete(by: manuId)));
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen.first, isNotNull);
      expect(seen.last, isNull);
    });

    test('should pass on a tournée it cannot read', () async {
      await db.doc('tournees/t49').set({'number': 49});
      await db.doc('tournees/t49/members/uid-manu').set(memberToDocument(manu));

      await expectLater(repository().find(tourneeId), throwsFormatException);
    });
  });

  group('save', () {
    test('should write the acceptance on the member only', () async {
      await repository().add(created);
      await db
          .doc('tournees/t49/members/uid-julie')
          .set(joinRequestDocument(julie, firstCode));
      final (accepted, change) = valueOf(
        team(members: [manu, julie])
            .accept(julieId, by: manuId, at: leaAcceptedAt),
      );

      final saved = await repository().save(accepted, change);
      await pumpEventQueue();

      expect(valueOf(saved), same(accepted));
      expect(await stored('tournees/t49/members/uid-julie'), {
        ...joinRequestDocument(julie, firstCode),
        'status': 'active',
        'acceptedBy': 'uid-manu',
        'acceptedAt': Timestamp.fromDate(leaAcceptedAt),
      });
    });

    for (final (name, act)
        in <
          (
            String,
            Result<(Tournee, TourneeChange), TourneeCommandFailure> Function(
              Tournee,
            ),
          )
        >[
          ('refused', (t) => t.refuse(julieId, by: leaId)),
          ('removed', (t) => t.remove(leaId, by: manuId)),
          ('leaving', (t) => t.leave(by: leaId)),
          ('cancelling', (t) => t.leave(by: julieId)),
        ]) {
      test('should delete the member document of a member $name', () async {
        await repository().add(created);
        for (final member in [lea, julie]) {
          await db
              .doc('tournees/t49/members/${member.id.value}')
              .set(memberToDocument(member));
        }
        final (after, change) = valueOf(act(team()));
        final gone = (change as MemberChange).member.id.value;

        final saved = await repository().save(after, change);
        await pumpEventQueue();

        expect(valueOf(saved), same(after));
        expect(await stored('tournees/t49/members/$gone'), isNull);
        expect(await stored('tournees/t49/members/uid-manu'), isNotNull);
      });
    }

    test('should replace the join code everywhere it is stored', () async {
      await repository().add(created);
      final (renewed, change) = valueOf(
        team().regenerateCode(by: manuId, random: ScriptedRandom(draws234567)),
      );

      final saved = await repository().save(renewed, change);

      expect(valueOf(saved), same(renewed));
      expect((await stored('tournees/t49'))!['joinCode'], '234567');
      expect(await stored('joinCodes/K7P2QX'), isNull);
      expect(await stored('joinCodes/234567'), joinCodeDocument(created));
    });

    test('should draw another code when the new code is taken', () async {
      await repository().add(created);
      await db.doc('joinCodes/234567').set({'tourneeId': 'other'});
      final (renewed, change) = valueOf(
        team().regenerateCode(by: manuId, random: ScriptedRandom(draws234567)),
      );
      // The adapter draws `K7P2QX` first, the old code: drawn again.
      final draws = [
        for (final character in 'K7P2QX'.split(''))
          JoinCode.alphabet.indexOf(character),
        for (final character in '765432'.split(''))
          JoinCode.alphabet.indexOf(character),
      ];

      final saved = valueOf(await repository(draws).save(renewed, change));

      // The tournée as stored, with the code the server took.
      expect(saved.joinCode, codeOf('765432'));
      expect(saved.id, tourneeId);
      expect(saved.members, renewed.members);
      expect((await stored('tournees/t49'))!['joinCode'], '765432');
      expect(await stored('joinCodes/765432'), joinCodeDocument(created));
      expect(await stored('joinCodes/234567'), {'tourneeId': 'other'});
      expect(await stored('joinCodes/K7P2QX'), isNull);
    });
  });

  test('should tell when a new code is asked offline', () async {
    await repository().add(created);
    final (renewed, change) = valueOf(
      team().regenerateCode(by: manuId, random: ScriptedRandom(draws234567)),
    );
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('joinCodes/234567'))
        .thenThrow(firestoreError('unavailable'));

    final saved = await repository().save(renewed, change);

    expect(failureOf(saved), TourneeWriteFailure.noNetwork);
    expect((await stored('tournees/t49'))!['joinCode'], 'K7P2QX');
  });

  test('should throw any other failure of a new code', () async {
    await repository().add(created);
    final (renewed, change) = valueOf(
      team().regenerateCode(by: manuId, random: ScriptedRandom(draws234567)),
    );
    whenCalling(Invocation.method(#get, null))
        .on(db.doc('joinCodes/234567'))
        .thenThrow(firestoreError('permission-denied'));

    await expectLater(
      repository().save(renewed, change),
      throwsA(isA<FirebaseException>()),
    );
  });

  group('delete', () {
    test('should delete the tournée and all it holds, nothing else', () async {
      await repository().add(created);
      await db.doc('tournees/t49/members/uid-lea').set(memberToDocument(lea));
      await db.doc('tournees/t49/campaigns/2026/streets/lilas').set({
        'name': 'Rue des Lilas',
      });
      await db.doc('tournees/t50/campaigns/2026/streets/roses').set({
        'name': 'Allée des Roses',
      });

      final deletion = valueOf(team().delete(by: manuId));

      final deleted = await repository().delete(deletion);

      expect(valueOf(deleted), same(deletion));
      for (final path in [
        'tournees/t49',
        'tournees/t49/members/uid-manu',
        'tournees/t49/members/uid-lea',
        'tournees/t49/campaigns/2026',
        'tournees/t49/campaigns/2026/streets/lilas',
        'joinCodes/K7P2QX',
        'tourneeKeys/villefranche_49',
      ]) {
        expect(await stored(path), isNull, reason: path);
      }
      expect(
        await stored('tournees/t50/campaigns/2026/streets/roses'),
        isNotNull,
      );
      expect(await stored('rescueCentres/villefranche'), isNotNull);
    });

    test('should delete in batches of at most 500 writes', () async {
      await repository().add(created);
      for (var i = 0; i < 520; i++) {
        await db.doc('tournees/t49/campaigns/2026/streets/s$i').set({'n': i});
      }

      await repository().delete(valueOf(team().delete(by: manuId)));

      final left = await db
          .collection('tournees/t49/campaigns/2026/streets')
          .get();
      expect(left.docs, isEmpty);
    });

    test('should tell and delete nothing when the server cannot be '
        'reached', () async {
      await repository().add(created);
      // Only the reads asked of the server fail (`get` with options), so
      // the test can still look at what is stored.
      whenCalling(Invocation.method(#get, [isA<GetOptions>()]))
          .on(db.doc('tournees/t49'))
          .thenThrow(firestoreError('unavailable'));

      final deleted = await repository().delete(
        valueOf(team().delete(by: manuId)),
      );

      expect(failureOf(deleted), TourneeWriteFailure.noNetwork);
      expect(await stored('tournees/t49'), isNotNull);
      expect(await stored('tournees/t49/campaigns/2026'), isNotNull);
    });

    test('should throw any other failure of the server', () async {
      await repository().add(created);
      whenCalling(Invocation.method(#get, null))
          .on(db.doc('tournees/t49'))
          .thenThrow(firestoreError('permission-denied'));

      await expectLater(
        repository().delete(valueOf(team().delete(by: manuId))),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
