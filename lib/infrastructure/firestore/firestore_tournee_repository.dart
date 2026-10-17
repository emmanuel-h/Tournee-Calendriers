import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/tournee_document_mapper.dart';

/// The [TourneeRepository] over Firestore (PLAN §6.2): `tournees/{id}` and
/// its `members`, with the `joinCodes`, `tourneeKeys` and `rescueCentres`
/// documents that make a tournée findable.
///
/// - **Creating** and **a new code** run in a transaction: it needs the
///   server (it fails at once offline instead of waiting in a queue) and
///   reads before it writes, so a number already taken, or a code another
///   tournée holds, is seen even when someone else writes it at the same
///   second (Firestore runs the transaction again when a document it read
///   changed meanwhile). A code already taken is replaced by a new one
///   drawn from [random], up to [maxCodeDraws] times: with 887 million
///   codes it does not happen in practice, and the user would have nothing
///   to do about it.
/// - **Accepting, refusing, removing, leaving, renaming** are applied on
///   the phone at once and sent when the network allows
///   ([sendInBackground]).
/// - **An admin joining** (PLAN §5.12) first asks the server for the
///   tournée, so offline it fails at once; then their member document is
///   sent like the other member writes.
/// - **Reading** follows the tournée document and its members with two
///   listeners, served from the phone's copy first.
final class FirestoreTourneeRepository implements TourneeRepository {
  /// [random] draws the replacement of a join code already taken:
  /// `Random.secure()` in the app (PLAN §5.2), a scripted one in tests.
  FirestoreTourneeRepository(this._db, {required this._random});

  /// The most codes drawn before giving up with a [StateError].
  static const maxCodeDraws = 10;

  final FirebaseFirestore _db;
  final Random _random;

  @override
  Future<Tournee?> find(TourneeId id) => watch(id).first;

  @override
  Stream<Tournee?> watch(TourneeId id) {
    late final StreamController<Tournee?> controller;
    StreamSubscription<Object?>? tourneeListener;
    StreamSubscription<Object?>? membersListener;
    DocumentSnapshot<Map<String, dynamic>>? tournee;
    QuerySnapshot<Map<String, dynamic>>? members;

    void emit() {
      // Local copies: Dart does not promote a variable a closure captures,
      // the copies are known non-null after the check.
      final (doc, team) = (tournee, members);
      // Both listeners must have answered once.
      if (doc == null || team == null) return;
      final data = doc.data();
      if (data == null) {
        controller.add(null);
        return;
      }
      try {
        controller.add(
          tourneeFromDocuments(id.value, data, {
            for (final member in team.docs) member.id: member.data(),
          }),
        );
      } on FormatException catch (error, trace) {
        controller.addError(error, trace);
      }
    }

    void failed(Object error, StackTrace trace) {
      if (isNoLongerReadable(error)) {
        controller.add(null);
      } else {
        controller.addError(error, trace);
      }
    }

    controller = StreamController<Tournee?>(
      onListen: () {
        tourneeListener = FirestoreLayout.tournee(_db, id).snapshots().listen((
          snapshot,
        ) {
          tournee = snapshot;
          emit();
        }, onError: failed);
        membersListener = FirestoreLayout.membersOf(_db, id).snapshots().listen(
          (snapshot) {
            members = snapshot;
            emit();
          },
          onError: failed,
        );
      },
      // A listener that leaves stops both listeners and frees the stream.
      onCancel: () async {
        await tourneeListener?.cancel();
        await membersListener?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Result<Tournee, AddTourneeFailure>> add(Tournee tournee) async {
    try {
      return await _db.runTransaction((transaction) async {
        final key = _db
            .collection(FirestoreLayout.tourneeKeys)
            .doc(tourneeKeyId(tournee.centre, tournee.number));
        if ((await transaction.get(key)).exists) {
          return const Err(AddTourneeFailure.alreadyExists);
        }
        final code = await _freeCode(transaction, tournee.joinCode);
        final stored = code == tournee.joinCode
            ? tournee
            : tournee.withJoinCode(code);
        final centre = _db
            .collection(FirestoreLayout.rescueCentres)
            .doc(stored.centre.key.value);
        final centreKnown = (await transaction.get(centre)).exists;

        final tourneeDoc = FirestoreLayout.tournee(_db, stored.id);
        transaction
          ..set(key, tourneeKeyDocument(stored))
          ..set(_joinCode(code), joinCodeDocument(stored))
          ..set(tourneeDoc, tourneeToDocument(stored))
          ..set(
            FirestoreLayout.membersOf(
              _db,
              stored.id,
            ).doc(stored.createdBy.value),
            // `!`: a tournée just created holds its creator (`createdBy`).
            memberToDocument(stored.memberOf(stored.createdBy)!),
          )
          ..set(
            tourneeDoc
                .collection(FirestoreLayout.campaigns)
                .doc('${stored.currentCampaign.value}'),
            firstCampaignDocument(stored),
          );
        // The first name written stays: the list shows one name per
        // station.
        if (!centreKnown) {
          transaction.set(centre, rescueCentreDocument(stored.centre));
        }
        return Ok(stored);
      });
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(AddTourneeFailure.noNetwork);
      if (isRefused(error)) return const Err(AddTourneeFailure.notAdmin);
      rethrow;
    }
  }

  @override
  Future<Result<Tournee, TourneeWriteFailure>> save(
    Tournee tournee,
    TourneeChange change,
  ) async {
    final members = FirestoreLayout.membersOf(_db, tournee.id);
    switch (change) {
      case MemberAccepted(:final member):
        sendInBackground(
          '$change',
          members.doc(member.id.value).update(acceptanceFields(member)),
        );
        return Ok(tournee);
      case MemberRenamed(:final member):
        sendInBackground(
          '$change',
          members.doc(member.id.value).update(displayNameFields(member)),
        );
        return Ok(tournee);
      case MemberRefused(:final member) ||
          MemberRemoved(:final member) ||
          MemberLeft(:final member):
        sendInBackground('$change', members.doc(member.id.value).delete());
        return Ok(tournee);
      case AdminJoined(:final member):
        try {
          // Asked of the server first: offline the admin is told at once
          // (« Pas de réseau », PLAN §5.12) instead of believing they
          // joined while the write waits on the phone.
          await FirestoreLayout.tournee(
            _db,
            tournee.id,
          ).get(const GetOptions(source: Source.server));
        } on FirebaseException catch (error) {
          if (_writeFailureOf(error) case final failure?) return Err(failure);
          rethrow;
        }
        sendInBackground(
          '$change',
          members.doc(member.id.value).set(memberToDocument(member)),
        );
        return Ok(tournee);
      case JoinCodeRegenerated(:final before, :final code):
        try {
          final free = await _db.runTransaction((transaction) async {
            final free = await _freeCode(transaction, code, old: before);
            transaction
              ..update(FirestoreLayout.tournee(_db, tournee.id), {
                'joinCode': free.value,
              })
              ..delete(_joinCode(before))
              ..set(_joinCode(free), joinCodeDocument(tournee));
            return free;
          });
          return Ok(free == code ? tournee : tournee.withJoinCode(free));
        } on FirebaseException catch (error) {
          if (_writeFailureOf(error) case final failure?) return Err(failure);
          rethrow;
        }
    }
  }

  /// Deletes the tournée and everything in it (PLAN §8.3). Needs the
  /// server: the lists are read from it, so nothing only the server knows
  /// is left behind.
  ///
  /// The campaigns and their streets go first, in batches. The members
  /// still in it (there may be none: everyone may leave, the creator too)
  /// go last, with the tournée, its code and its reservation in one batch:
  /// a member's phone, which learns it lost the tournée when its own
  /// member document goes, finds the reservation gone at the same instant
  /// and says « supprimée », not « retiré » (`watchMembership`). Only the
  /// documents that exist are deleted: the security rules refuse deleting
  /// a member document that is not there. A team is far below the 500
  /// writes of a batch.
  @override
  Future<Result<TourneeDeleted, TourneeWriteFailure>> delete(
    TourneeDeleted deletion,
  ) async {
    final tournee = deletion.tournee;
    const server = GetOptions(source: Source.server);
    final tourneeDoc = FirestoreLayout.tournee(_db, tournee.id);
    try {
      // Asked of the server first: offline it fails at once, before
      // anything is deleted (a batch would wait on the phone instead).
      await tourneeDoc.get(server);
      await _deleteAll(tournee, tourneeDoc);
      return Ok(deletion);
    } on FirebaseException catch (error) {
      if (_writeFailureOf(error) case final failure?) return Err(failure);
      rethrow;
    }
  }

  /// Deletes what [tournee] holds, then [tourneeDoc] with its code, its
  /// reservation and its members (see [delete]). A phone no longer an
  /// admin's is refused at the first batch, before anything goes: a
  /// member may read the tournée but not delete its campaigns.
  Future<void> _deleteAll(
    Tournee tournee,
    DocumentReference<Map<String, dynamic>> tourneeDoc,
  ) async {
    const server = GetOptions(source: Source.server);
    final contents = <DocumentReference<Map<String, dynamic>>>[];
    final campaigns = await tourneeDoc
        .collection(FirestoreLayout.campaigns)
        .get(server);
    for (final campaign in campaigns.docs) {
      final streets = await campaign.reference
          .collection(FirestoreLayout.streets)
          .get(server);
      contents
        ..addAll([for (final street in streets.docs) street.reference])
        ..add(campaign.reference);
    }
    final members = await FirestoreLayout.membersOf(
      _db,
      tournee.id,
    ).get(server);
    // A batch holds at most 500 writes.
    for (var start = 0; start < contents.length; start += 500) {
      final batch = _db.batch();
      for (final doc in contents.skip(start).take(500)) {
        batch.delete(doc);
      }
      await batch.commit();
    }
    final last = _db.batch()
      ..delete(_joinCode(tournee.joinCode))
      ..delete(
        _db
            .collection(FirestoreLayout.tourneeKeys)
            .doc(tourneeKeyId(tournee.centre, tournee.number)),
      )
      ..delete(tourneeDoc);
    for (final member in members.docs) {
      last.delete(member.reference);
    }
    await last.commit();
  }

  /// What [error] of a write that needs the server tells the use case: no
  /// network, or not an admin. Null for any other failure, which the
  /// caller throws on.
  TourneeWriteFailure? _writeFailureOf(FirebaseException error) {
    if (isNoNetwork(error)) return TourneeWriteFailure.noNetwork;
    if (isRefused(error)) return TourneeWriteFailure.notAdmin;
    return null;
  }

  DocumentReference<Map<String, dynamic>> _joinCode(JoinCode code) =>
      _db.collection(FirestoreLayout.joinCodes).doc(code.value);

  /// [first] when no tournée holds it, otherwise a new code drawn from
  /// [_random] that none holds and that is not [old].
  Future<JoinCode> _freeCode(
    Transaction transaction,
    JoinCode first, {
    JoinCode? old,
  }) async {
    var code = first;
    for (var draw = 0; draw < maxCodeDraws; draw++) {
      if (code != old && !(await transaction.get(_joinCode(code))).exists) {
        return code;
      }
      code = JoinCode.generate(_random);
    }
    throw StateError('No free join code after $maxCodeDraws draws');
  }
}
