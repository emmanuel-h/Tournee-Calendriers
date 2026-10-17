import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/tournee_document_mapper.dart';

/// The [TourneeDirectory] over Firestore, on the phone (Spark plan, PLAN
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
final class FirestoreTourneeDirectory implements TourneeDirectory {
  const FirestoreTourneeDirectory(this._db);

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

  @override
  Future<void> requestToJoin(JoinPreview preview, Member request) async {
    if (request.isActive) {
      throw ArgumentError.value(request, 'request', 'must be pending');
    }
    sendInBackground(
      'request to join ${preview.tourneeId.value}',
      _member(
        preview.tourneeId,
        request.id,
      ).set(joinRequestDocument(request, preview.code)),
    );
  }

  @override
  Stream<MemberStatus?> watchRequest(TourneeId tournee, MemberId member) =>
      _member(tournee, member)
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

  @override
  Future<void> cancelRequest(TourneeId tournee, MemberId member) async {
    sendInBackground(
      'cancel the request to join ${tournee.value}',
      _member(tournee, member).delete(),
    );
  }

  /// Follows the member's own document, which the rules let them read
  /// whatever happens to the tournée (PLAN §8.2). Once the server says it
  /// is gone, the reservation of the tournée's number tells why: it stays
  /// while the tournée does, and goes with it (`lossFromReservation`).
  ///
  /// A `permission-denied` here is not taken as a loss: the member may
  /// always read their own document, so it can only mean something else
  /// (App Check refusing the app, a rules change), which must not make
  /// the phone forget a tournée. It is passed on as an error.
  @override
  Stream<TourneeLoss> watchMembership(
    TourneeSummary tournee,
    MemberId member,
  ) => tournee.isVisiting
      ? _watchVisit(tournee, member)
      : _member(tournee.id, member)
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
              final reservation = await _db
                  .collection(FirestoreLayout.tourneeKeys)
                  .doc(tourneeKeyId(tournee.centre, tournee.number))
                  .get(_server);
              return lossFromReservation(tournee.id, reservation.data());
            });

  /// A tournée the admin [member] only visits (PLAN §5.12): they have no
  /// member document to follow. The tournée tells it was deleted once the
  /// server has it no more; their own `admins/{uid}`, which the rules let
  /// any signed-in phone read, tells they are no longer an admin once the
  /// server has it no more. Both listeners run at once, in one stream.
  Stream<TourneeLoss> _watchVisit(TourneeSummary tournee, MemberId member) {
    bool gone(DocumentSnapshot<Object?> doc) => isGoneOnServer(
      exists: doc.exists,
      fromCache: doc.metadata.isFromCache,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
    final losses = [
      FirestoreLayout.tournee(
        _db,
        tournee.id,
      ).snapshots().where(gone).map((_) => TourneeLoss.deleted),
      FirestoreLayout.admin(
        _db,
        member,
      ).snapshots().where(gone).map((_) => TourneeLoss.adminRevoked),
    ];
    late final StreamController<TourneeLoss> controller;
    final listeners = <StreamSubscription<TourneeLoss>>[];
    controller = StreamController<TourneeLoss>(
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
  Stream<MemberName> watchOwnName(TourneeId tournee, MemberId member) =>
      _member(tournee, member).snapshots().expand(
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
    TourneeNumber number,
  ) async {
    try {
      final doc = await _db
          .collection(FirestoreLayout.tourneeKeys)
          .doc(tourneeKeyId(centre, number))
          .get(_server);
      return Ok(doc.exists);
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(DirectoryFailure.noNetwork);
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
  Future<Result<List<TourneeOverview>, DirectoryFailure>> allTournees(
    MemberId caller,
  ) async {
    try {
      final tournees = await _db
          .collection(FirestoreLayout.tournees)
          .get(_server);
      final teams = await Future.wait([
        for (final doc in tournees.docs)
          FirestoreLayout.membersOf(_db, TourneeId(doc.id)).get(_server),
      ]);
      final overviews = <TourneeOverview>[];
      for (final (index, doc) in tournees.docs.indexed) {
        try {
          final tournee = tourneeFromDocuments(doc.id, doc.data(), {
            for (final member in teams[index].docs) member.id: member.data(),
          });
          overviews.add(overviewOf(tournee, caller));
        } on FormatException catch (error) {
          debugPrint('Unreadable tournée ${doc.id}: $error');
        }
      }
      return Ok(List.unmodifiable(overviews));
    } on FirebaseException catch (error) {
      if (isNoNetwork(error)) return const Err(DirectoryFailure.noNetwork);
      rethrow;
    }
  }

  DocumentReference<Map<String, dynamic>> _member(
    TourneeId tournee,
    MemberId member,
  ) => FirestoreLayout.membersOf(_db, tournee).doc(member.value);
}
