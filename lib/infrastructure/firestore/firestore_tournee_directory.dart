import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/tournee_document_mapper.dart';

/// The [TourneeDirectory] over Firestore, on the phone (Spark plan, PLAN
/// Q20): a join code is read with an exact `get` of `joinCodes/{code}`
/// (listing them is refused by the rules), the request is the newcomer's
/// own pending member document.
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
          .map<MemberStatus?>((doc) {
            final data = doc.data();
            return data == null
                ? null
                : memberFromDocument(doc.id, data).status;
          })
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

  DocumentReference<Map<String, dynamic>> _member(
    TourneeId tournee,
    MemberId member,
  ) => FirestoreLayout.membersOf(_db, tournee).doc(member.value);
}
