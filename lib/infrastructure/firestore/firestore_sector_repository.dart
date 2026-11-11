import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_repository.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_part_index.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/sector_document_mapper.dart';

/// The [SectorRepository] over Firestore (PLAN §6.2): `sectors/{id}` and
/// its `members`, with the `joinCodes`, `sectorKeys` and `rescueCentres`
/// documents that make a secteur findable.
///
/// - **Creating** and **a new code** run in a transaction: it needs the
///   server (it fails at once offline instead of waiting in a queue) and
///   reads before it writes, so a number already taken, or a code another
///   secteur holds, is seen even when someone else writes it at the same
///   second (Firestore runs the transaction again when a document it read
///   changed meanwhile). A code already taken is replaced by a new one
///   drawn from [random], up to [maxCodeDraws] times: with 887 million
///   codes it does not happen in practice, and the user would have nothing
///   to do about it.
/// - **Accepting, refusing, removing, leaving**, and **adding or removing
///   a commune** are applied on the phone at once and sent when the
///   network allows ([sendInBackground]). The name a member refused,
///   removed or leaving held goes with their document, in one batch.
/// - **Renaming** and **an admin joining** (PLAN §5.9, §5.12) hold a name
///   in the secteur (#148, `names/{key}`, the name's `MemberName.key`): a
///   transaction reads the name's entry and writes the member with it, so
///   it fails at once offline, and a name another member holds is refused
///   (by this read, or by the security rules for one taken at the same
///   second).
/// - **Reading** follows the secteur document and its members with two
///   listeners, served from the phone's copy first.
final class FirestoreSectorRepository implements SectorRepository {
  /// [random] draws the replacement of a join code already taken:
  /// `Random.secure()` in the app (PLAN §5.2), a scripted one in tests.
  FirestoreSectorRepository(this._db, {required this._random});

  /// The most codes drawn before giving up with a [StateError].
  static const maxCodeDraws = 10;

  /// How many times deleting a secteur lists what it holds and deletes
  /// it, at most: once, then again for what a teammate wrote meanwhile.
  /// Bounded, so a phone that never stops writing cannot keep the
  /// deletion going; what it writes after the last pass stays (a
  /// server-side recursive delete would be the full answer, on Blaze).
  static const maxDeletePasses = 3;

  final FirebaseFirestore _db;
  final Random _random;

  @override
  Future<Sector?> find(SectorId id) => watch(id).first;

  @override
  Stream<Sector?> watch(SectorId id) {
    late final StreamController<Sector?> controller;
    StreamSubscription<Object?>? sectorListener;
    StreamSubscription<Object?>? membersListener;
    DocumentSnapshot<Map<String, dynamic>>? sector;
    QuerySnapshot<Map<String, dynamic>>? members;

    void emit() {
      // Local copies: Dart does not promote a variable a closure captures,
      // the copies are known non-null after the check.
      final (doc, team) = (sector, members);
      // Both listeners must have answered once.
      if (doc == null || team == null) return;
      final data = doc.data();
      if (data == null) {
        controller.add(null);
        return;
      }
      try {
        controller.add(
          sectorFromDocuments(id.value, data, {
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

    controller = StreamController<Sector?>(
      onListen: () {
        sectorListener = FirestoreLayout.sector(_db, id).snapshots().listen((
          snapshot,
        ) {
          sector = snapshot;
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
        await sectorListener?.cancel();
        await membersListener?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Result<Sector, AddSectorFailure>> add(Sector sector) async {
    try {
      return await _db.runTransaction((transaction) async {
        final key = _db
            .collection(FirestoreLayout.sectorKeys)
            .doc(sectorKeyId(sector.centre, sector.number));
        if ((await transaction.get(key)).exists) {
          return const Err(AddSectorFailure.alreadyExists);
        }
        final code = await _freeCode(transaction, sector.joinCode);
        final stored = code == sector.joinCode
            ? sector
            : sector.withJoinCode(code);
        final centre = _db
            .collection(FirestoreLayout.rescueCentres)
            .doc(stored.centre.key.value);
        final centreKnown = (await transaction.get(centre)).exists;

        final sectorDoc = FirestoreLayout.sector(_db, stored.id);
        // `!`: a secteur just created holds its creator (`createdBy`).
        final creator = stored.memberOf(stored.createdBy)!;
        transaction
          ..set(key, sectorKeyDocument(stored))
          ..set(_joinCode(code), joinCodeDocument(stored))
          ..set(sectorDoc, sectorToDocument(stored))
          ..set(
            FirestoreLayout.membersOf(
              _db,
              stored.id,
            ).doc(stored.createdBy.value),
            memberToDocument(creator),
          )
          // The creator's name, held in the secteur from the start (#148).
          ..set(
            FirestoreLayout.nameIn(_db, stored.id, creator.name),
            nameEntryDocument(creator.id),
          )
          ..set(
            sectorDoc
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
      if (isNoNetwork(error)) return const Err(AddSectorFailure.noNetwork);
      if (isRefused(error)) return const Err(AddSectorFailure.notAdmin);
      rethrow;
    }
  }

  @override
  Future<Result<Sector, SectorWriteFailure>> save(
    Sector sector,
    SectorChange change,
  ) async {
    final members = FirestoreLayout.membersOf(_db, sector.id);
    switch (change) {
      case MemberAccepted(:final member):
        sendInBackground(
          '$change',
          members.doc(member.id.value).update(acceptanceFields(member)),
        );
        return Ok(sector);
      case MemberRenamed(:final member):
        // A refusal means another member took the name at the same second
        // (the security rules), or the member is no longer in the secteur.
        return _holdingName(
          sector,
          member,
          refused: SectorWriteFailure.nameTaken,
          (transaction) async {
            final doc = members.doc(member.id.value);
            final stored = (await transaction.get(doc)).data();
            // Gone meanwhile (removed, left): nothing to rename, and the
            // phone hears of the loss from its own listener.
            if (stored == null) return false;
            // The name held until now is freed when the rename changes its
            // key (« Léa » to « LÉA » keeps it), and only when it is the
            // member's. Read before any write, as a transaction requires.
            if (stored['displayName'] case final String text) {
              if (MemberName.create(text) case Ok(:final value)
                  when value.key != member.name.key) {
                final old = FirestoreLayout.nameIn(_db, sector.id, value);
                final holder = nameHolderOf(
                  (await transaction.get(old)).data(),
                );
                if (holder == member.id) transaction.delete(old);
              }
            }
            transaction.update(doc, displayNameFields(member));
            return true;
          },
        );
      case MemberRefused(:final member) ||
          MemberRemoved(:final member) ||
          MemberLeft(:final member):
        // The name goes with the member, in one batch: it is free again in
        // the secteur (#148).
        sendInBackground(
          '$change',
          (_db.batch()
                ..delete(members.doc(member.id.value))
                ..delete(FirestoreLayout.nameIn(_db, sector.id, member.name)))
              .commit(),
        );
        return Ok(sector);
      case AdminJoined(:final member):
        // A refusal means the phone is no longer an admin's: an admin may
        // read every name of the secteur, so a taken one is seen by the
        // read and never reaches the rules.
        return _holdingName(
          sector,
          member,
          refused: SectorWriteFailure.notAdmin,
          (transaction) async {
            transaction.set(
              members.doc(member.id.value),
              memberToDocument(member),
            );
            return true;
          },
        );
      case CommuneAdded(:final commune):
        // `arrayUnion`: only this entry is added to the stored list, so a
        // teammate's commune added at the same time stays.
        sendInBackground(
          '$change',
          FirestoreLayout.sector(_db, sector.id).update({
            'communes': FieldValue.arrayUnion([communeEntry(commune)]),
          }),
        );
        return Ok(sector);
      case CommuneRemoved(:final commune):
        // `arrayRemove` takes out the entries equal to this one, as it was
        // read: the security rules refuse it when it would empty the list.
        sendInBackground(
          '$change',
          FirestoreLayout.sector(_db, sector.id).update({
            'communes': FieldValue.arrayRemove([communeEntry(commune)]),
          }),
        );
        return Ok(sector);
      case JoinCodeRegenerated(:final before, :final code):
        try {
          final free = await _db.runTransaction((transaction) async {
            final free = await _freeCode(transaction, code, old: before);
            transaction
              ..update(FirestoreLayout.sector(_db, sector.id), {
                'joinCode': free.value,
              })
              ..delete(_joinCode(before))
              ..set(_joinCode(free), joinCodeDocument(sector));
            return free;
          });
          return Ok(free == code ? sector : sector.withJoinCode(free));
        } on FirebaseException catch (error) {
          if (_writeFailureOf(error) case final failure?) return Err(failure);
          rethrow;
        }
    }
  }

  /// Deletes the secteur and everything in it (PLAN §8.3). Needs the
  /// server: the lists are read from it, so nothing only the server knows
  /// is left behind.
  ///
  /// The secteur's entries in the shared index go first, and are waited
  /// for: one that fails fails the deletion as a batch would (no network,
  /// not an admin), before its streets go, so a new try finds them. Then the
  /// campaigns, their streets and their validated tournées, in batches,
  /// listed again for what a teammate wrote meanwhile. The members
  /// still in it (there may be none: everyone may leave, the creator too)
  /// go last, with the secteur, its code and its reservation in one batch:
  /// a member's phone, which learns it lost the secteur when its own
  /// member document goes, finds the reservation gone at the same instant
  /// and says « supprimée », not « retiré » (`watchMembership`). Only the
  /// documents that exist are deleted: the security rules refuse deleting
  /// a member document that is not there. A team is far below the 500
  /// writes of a batch.
  @override
  Future<Result<SectorDeleted, SectorWriteFailure>> delete(
    SectorDeleted deletion,
  ) async {
    final sector = deletion.sector;
    const server = GetOptions(source: Source.server);
    final sectorDoc = FirestoreLayout.sector(_db, sector.id);
    try {
      // Asked of the server first: offline it fails at once, before
      // anything is deleted (a batch would wait on the phone instead).
      await sectorDoc.get(server);
      await _deleteAll(sector, sectorDoc);
      return Ok(deletion);
    } on FirebaseException catch (error) {
      if (_writeFailureOf(error) case final failure?) return Err(failure);
      rethrow;
    }
  }

  /// Deletes what [sector] holds, then [sectorDoc] with its code, its
  /// reservation and its members (see [delete]). A phone no longer an
  /// admin's is refused at the first batch, before anything goes: a
  /// member may read the secteur but not delete its campaigns.
  ///
  /// A teammate may write while it runs (a street added, a request to
  /// join): what they wrote after a list was read would stay, unreachable.
  /// So the contents are listed and deleted again until a list comes back
  /// empty, and the members once more after the secteur went, each at
  /// most [maxDeletePasses] times.
  Future<void> _deleteAll(
    Sector sector,
    DocumentReference<Map<String, dynamic>> sectorDoc,
  ) async {
    // The id of every campaign seen, kept across passes: a street written
    // under a campaign whose document is already deleted is not found by
    // listing the campaigns (Firestore lists only documents that exist).
    final campaigns = <String>{};
    await _deleteUntilNone(() => _contentsOf(sector, sectorDoc, campaigns));
    // The team's collections, named once: each list below reads them again.
    final team = [
      FirestoreLayout.membersOf(_db, sector.id),
      FirestoreLayout.namesOf(_db, sector.id),
    ];
    final listed = await _listed(team);
    final last = _db.batch()
      ..delete(_joinCode(sector.joinCode))
      ..delete(
        _db
            .collection(FirestoreLayout.sectorKeys)
            .doc(sectorKeyId(sector.centre, sector.number)),
      )
      ..delete(sectorDoc);
    for (final doc in listed) {
      last.delete(doc);
    }
    await last.commit();
    // A request to join, with its name, sent between the list and the
    // batch. None can come later: the rules check it against the secteur,
    // now gone.
    await _deleteUntilNone(() => _listed(team));
  }

  /// The documents of [collections] (the members and the names they hold,
  /// #148), listed from the server.
  Future<List<DocumentReference<Map<String, dynamic>>>> _listed(
    List<CollectionReference<Map<String, dynamic>>> collections,
  ) async {
    const server = GetOptions(source: Source.server);
    final lists = await Future.wait([
      for (final collection in collections) collection.get(server),
    ]);
    return [
      for (final list in lists)
        for (final doc in list.docs) doc.reference,
    ];
  }

  /// What [sector] holds, listed from the server: its campaigns, with
  /// their streets and validated tournées (#63) — a sub-collection is not
  /// deleted with its document, it would stay, unreachable. [campaigns]
  /// gathers the id of every campaign seen.
  ///
  /// Before it answers, the secteur's entry in the shared index of each
  /// listed street from the BAN is released (PLAN §5.15), and awaited:
  /// refused or offline, it fails the deletion while the streets are
  /// still there to find it again, instead of leaving a deleted secteur
  /// in other secteurs' overlap warnings.
  Future<List<DocumentReference<Map<String, dynamic>>>> _contentsOf(
    Sector sector,
    DocumentReference<Map<String, dynamic>> sectorDoc,
    Set<String> campaigns,
  ) async {
    const server = GetOptions(source: Source.server);
    final campaignsOf = sectorDoc.collection(FirestoreLayout.campaigns);
    final listed = await campaignsOf.get(server);
    final contents = [for (final campaign in listed.docs) campaign.reference];
    final banIds = <String>{};
    campaigns.addAll([for (final campaign in listed.docs) campaign.id]);
    for (final campaign in campaigns) {
      for (final name in [FirestoreLayout.streets, FirestoreLayout.rounds]) {
        final docs = await campaignsOf
            .doc(campaign)
            .collection(name)
            .get(server);
        contents.addAll([for (final doc in docs.docs) doc.reference]);
        if (name == FirestoreLayout.streets) {
          banIds.addAll([
            for (final doc in docs.docs)
              if (doc.data()['banId'] case final String banId) banId,
          ]);
        }
      }
    }
    await Future.wait([
      for (final banId in banIds)
        releaseStreetPart(_db, sector.id, BanStreetId(banId)),
    ]);
    return contents;
  }

  /// Deletes what [listed] gives, in batches, and lists again, until it
  /// gives nothing or [maxDeletePasses] lists were deleted.
  Future<void> _deleteUntilNone(
    Future<List<DocumentReference<Map<String, dynamic>>>> Function() listed,
  ) async {
    for (var pass = 0; pass < maxDeletePasses; pass++) {
      final docs = await listed();
      if (docs.isEmpty) return;
      // A batch holds at most 500 writes.
      for (var start = 0; start < docs.length; start += 500) {
        final batch = _db.batch();
        for (final doc in docs.skip(start).take(500)) {
          batch.delete(doc);
        }
        await batch.commit();
      }
    }
  }

  /// Holds the name of [member] in [sector] (#148) and runs [write] in the
  /// same transaction, so the member and the name are written together or
  /// not at all.
  ///
  /// The name's entry is read first: held by another member, nothing is
  /// written and it fails with [SectorWriteFailure.nameTaken]; free, it is
  /// created for [member]; already theirs, it stays. [write] reads what it
  /// needs, writes the member, and returns false when there is nothing to
  /// write after all: then the name is not held either.
  ///
  /// A transaction needs the server: offline it fails at once with
  /// [SectorWriteFailure.noNetwork]. A refusal of the security rules fails
  /// with [refused], which only the caller can word.
  Future<Result<Sector, SectorWriteFailure>> _holdingName(
    Sector sector,
    Member member,
    Future<bool> Function(Transaction transaction) write, {
    required SectorWriteFailure refused,
  }) async {
    final entry = FirestoreLayout.nameIn(_db, sector.id, member.name);
    try {
      return await _db.runTransaction<Result<Sector, SectorWriteFailure>>((
        transaction,
      ) async {
        final holder = nameHolderOf((await transaction.get(entry)).data());
        if (holder != null && holder != member.id) {
          return const Err(SectorWriteFailure.nameTaken);
        }
        if (await write(transaction) && holder == null) {
          transaction.set(entry, nameEntryDocument(member.id));
        }
        return Ok(sector);
      });
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(SectorWriteFailure.noNetwork);
      if (isRefused(error)) return Err(refused);
      rethrow;
    }
  }

  /// What [error] of a write that needs the server tells the use case: no
  /// network, or not an admin. Null for any other failure, which the
  /// caller throws on.
  SectorWriteFailure? _writeFailureOf(FirebaseException error) {
    if (isNoNetwork(error)) return SectorWriteFailure.noNetwork;
    if (isRefused(error)) return SectorWriteFailure.notAdmin;
    return null;
  }

  DocumentReference<Map<String, dynamic>> _joinCode(JoinCode code) =>
      _db.collection(FirestoreLayout.joinCodes).doc(code.value);

  /// [first] when no secteur holds it, otherwise a new code drawn from
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
