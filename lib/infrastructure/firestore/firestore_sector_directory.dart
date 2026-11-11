import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/join_request.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/sector_document_mapper.dart';

/// The [SectorDirectory] over Firestore, on the phone (Spark plan, PLAN
/// Q20): a join code is read with an exact `get` of `joinCodes/{code}`
/// (listing them is refused by the rules), the request is the newcomer's
/// own pending member document. A member follows their own member
/// document too, to learn they were removed or the tournée deleted; an
/// admin who only visits a tournée follows the tournée and their own
/// `admins/{uid}` instead (PLAN §5.12). An admin lists every tournée.
///
/// What must be true *now* (a code, a number taken) is asked of the server
/// (`Source.server`): an answer from the phone's copy could be stale. The
/// request and its cancellation are queued like any write.
final class FirestoreSectorDirectory implements SectorDirectory {
  const FirestoreSectorDirectory(this._db);

  final FirebaseFirestore _db;

  static const _server = GetOptions(source: Source.server);

  @override
  Future<Result<JoinPreview, JoinFailure>> preview(JoinCode code) async {
    try {
      final doc = await _db
          .collection(FirestoreLayout.joinCodes)
          .doc(code.value)
          .get(_server);
      final data = doc.data();
      if (data == null) return const Err(JoinFailure.unknownCode);
      return Ok(joinPreviewFromDocument(code, data));
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(JoinFailure.noNetwork);
      rethrow;
    }
  }

  /// A transaction: the name's entry in the secteur is read first, then the
  /// request and the entry are written together (#148). The rules let a
  /// newcomer read an entry only while it is free or theirs, so a refused
  /// read means another member holds the name; a refused write too, unless
  /// the code stopped working meanwhile, which a read of the code tells.
  @override
  Future<Result<void, JoinRequestFailure>> requestToJoin(
    JoinRequest request,
  ) async {
    final member = request.member;
    final entry = FirestoreLayout.nameIn(_db, request.sector, member.name);
    try {
      return await _db.runTransaction<Result<void, JoinRequestFailure>>((
        transaction,
      ) async {
        final holder = nameHolderOf((await transaction.get(entry)).data());
        if (holder != null && holder != member.id) {
          return const Err(JoinRequestFailure.nameTaken);
        }
        if (holder == null) {
          transaction.set(entry, nameEntryDocument(member.id));
        }
        transaction.set(
          _member(request.sector, member.id),
          joinRequestDocument(request),
        );
        return const Ok(null);
      });
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(JoinRequestFailure.noNetwork);
      if (!isRefused(error)) rethrow;
      return switch (await preview(request.code)) {
        Ok(:final value) when value.sectorId == request.sector => const Err(
          JoinRequestFailure.nameTaken,
        ),
        Ok() || Err(failure: JoinFailure.unknownCode) => const Err(
          JoinRequestFailure.unknownCode,
        ),
        Err(failure: JoinFailure.noNetwork) => const Err(
          JoinRequestFailure.noNetwork,
        ),
      };
    }
  }

  @override
  Stream<MemberStatus?> watchRequest(SectorId sector, MemberId member) =>
      _member(sector, member)
          .snapshots()
          // A snapshot of the phone's copy without the document tells
          // nothing: an offline start must never drop a pending request.
          .expand<MemberStatus?>(
            (doc) => requestStatusesIn(
              doc.id,
              doc.data(),
              fromCache: doc.metadata.isFromCache,
            ),
          )
          .transform(
            StreamTransformer.fromHandlers(
              handleError: (error, trace, sink) {
                // No longer readable: the request is gone.
                if (isNoLongerReadable(error)) {
                  sink.add(null);
                } else {
                  sink.addError(error, trace);
                }
              },
            ),
          );

  /// The request and the name it held go in one batch, queued like any
  /// write.
  @override
  Future<void> cancelRequest(
    SectorId sector,
    MemberId member,
    MemberName? name,
  ) async {
    final batch = _db.batch()..delete(_member(sector, member));
    if (name != null) batch.delete(FirestoreLayout.nameIn(_db, sector, name));
    sendInBackground(
      'cancel the request to join ${sector.value}',
      batch.commit(),
    );
  }

  /// Follows the member's own document, which the rules let them read
  /// whatever happens to the tournée (PLAN §8.2). Once the server says it
  /// is gone, a read of the tournée itself tells why (#147,
  /// `lossFromSectorRead`): refused (it is there, without them) or there,
  /// they were removed; not there, it was deleted. The reservation of its
  /// number told it before, but only admins may read it now: it names the
  /// tournée's id.
  ///
  /// A `permission-denied` on the member's own document is not taken as a
  /// loss: the member may always read it, so it can only mean something
  /// else (App Check refusing the app, a rules change), which must not
  /// make the phone forget a tournée. It is passed on as an error. On the
  /// read of the tournée it is the answer: the server, which just said the
  /// document is gone, is reachable and accepts the app.
  @override
  Stream<SectorLoss> watchMembership(SectorSummary sector, MemberId member) =>
      sector.isVisiting
      ? _watchVisit(sector, member)
      : _member(sector.id, member)
            .snapshots()
            .where(
              (doc) => isGoneOnServer(
                exists: doc.exists,
                fromCache: doc.metadata.isFromCache,
                hasPendingWrites: doc.metadata.hasPendingWrites,
              ),
            )
            // `asyncMap`: one read of the server per snapshot, in order.
            .asyncMap((_) async {
              try {
                final doc = await FirestoreLayout.sector(
                  _db,
                  sector.id,
                ).get(_server);
                return lossFromSectorRead(refused: false, exists: doc.exists);
              } on FirebaseException catch (error) {
                if (!isRefused(error)) rethrow;
                return lossFromSectorRead(refused: true, exists: true);
              }
            });

  /// A tournée the admin [member] only visits (PLAN §5.12): they have no
  /// member document to follow. The tournée tells it was deleted once the
  /// server has it no more; their own `admins/{uid}`, which the rules let
  /// any signed-in phone read, tells they are no longer an admin once the
  /// server has it no more. Both listeners run at once, in one stream.
  Stream<SectorLoss> _watchVisit(SectorSummary sector, MemberId member) {
    bool gone(DocumentSnapshot<Object?> doc) => isGoneOnServer(
      exists: doc.exists,
      fromCache: doc.metadata.isFromCache,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
    final losses = [
      FirestoreLayout.sector(
        _db,
        sector.id,
      ).snapshots().where(gone).map((_) => SectorLoss.deleted),
      FirestoreLayout.admin(
        _db,
        member,
      ).snapshots().where(gone).map((_) => SectorLoss.adminRevoked),
    ];
    late final StreamController<SectorLoss> controller;
    final listeners = <StreamSubscription<SectorLoss>>[];
    controller = StreamController<SectorLoss>(
      onListen: () => listeners.addAll([
        for (final stream in losses)
          stream.listen(controller.add, onError: controller.addError),
      ]),
      onCancel: () async {
        for (final listener in listeners) {
          await listener.cancel();
        }
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Follows the member's own document, as [watchMembership] does, for
  /// the name the server holds (`confirmedNamesIn`). `expand`: a snapshot
  /// gives one name or none.
  @override
  Stream<MemberName> watchOwnName(SectorId sector, MemberId member) =>
      _member(sector, member).snapshots().expand(
        (doc) => confirmedNamesIn(
          doc.id,
          doc.data(),
          fromCache: doc.metadata.isFromCache,
          hasPendingWrites: doc.metadata.hasPendingWrites,
        ),
      );

  @override
  Future<Result<bool, DirectoryFailure>> isTaken(
    RescueCentre centre,
    SectorNumber number,
  ) async {
    try {
      final doc = await _db
          .collection(FirestoreLayout.sectorKeys)
          .doc(sectorKeyId(centre, number))
          .get(_server);
      return Ok(doc.exists);
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(DirectoryFailure.noNetwork);
      // Only an admin may read a reservation (#147): the phone is no
      // longer one.
      if (isRefused(error)) return const Err(DirectoryFailure.notAdmin);
      rethrow;
    }
  }

  @override
  Future<Result<List<RescueCentre>, DirectoryFailure>> rescueCentres() async {
    try {
      final snapshot = await _db
          .collection(FirestoreLayout.rescueCentres)
          .get(_server);
      final centres = <RescueCentre>[];
      for (final doc in snapshot.docs) {
        try {
          centres.add(rescueCentreFromDocument(doc.data()));
        } on FormatException catch (error) {
          // One bad entry must not hide the others: it is only a list to
          // pick from.
          debugPrint('Unreadable centre de secours ${doc.id}: $error');
        }
      }
      centres.sort((a, b) => searchKey(a.name).compareTo(searchKey(b.name)));
      return Ok(List.unmodifiable(centres));
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(DirectoryFailure.noNetwork);
      rethrow;
    }
  }

  /// Reads every tournée from the server, then the members of each (at the
  /// same time), as the security rules let only an admin do. A tournée
  /// that cannot be read is left out, not fatal: it is only a list.
  @override
  Future<Result<List<SectorOverview>, DirectoryFailure>> allSectors(
    MemberId caller,
  ) async {
    try {
      final sectors = await _db
          .collection(FirestoreLayout.sectors)
          .get(_server);
      final teams = await Future.wait([
        for (final doc in sectors.docs)
          FirestoreLayout.membersOf(_db, SectorId(doc.id)).get(_server),
      ]);
      final overviews = <SectorOverview>[];
      for (final (index, doc) in sectors.docs.indexed) {
        try {
          final sector = sectorFromDocuments(doc.id, doc.data(), {
            for (final member in teams[index].docs) member.id: member.data(),
          });
          overviews.add(overviewOf(sector, caller));
        } on FormatException catch (error) {
          debugPrint('Unreadable tournée ${doc.id}: $error');
        }
      }
      return Ok(List.unmodifiable(overviews));
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(DirectoryFailure.noNetwork);
      // Only an admin may list the tournées: the phone is no longer one.
      if (isRefused(error)) return const Err(DirectoryFailure.notAdmin);
      rethrow;
    }
  }

  DocumentReference<Map<String, dynamic>> _member(
    SectorId sector,
    MemberId member,
  ) => FirestoreLayout.membersOf(_db, sector).doc(member.value);
}
