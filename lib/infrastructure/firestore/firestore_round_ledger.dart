import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/round_document_mapper.dart';

/// The [RoundLedger] over Firestore: one document per validated tournée,
/// `sectors/{id}/campaigns/{year}/rounds/{roundId}` (PLAN §6.2), seen by
/// the whole secteur in « Collecte », corrected afterwards by field
/// updates (#168), never by writing it whole again.
///
/// The phone keeps a validated summary itself until [record] says the
/// server has it (`OpenRoundStore`, #143), so a refusal is never lost; the
/// Firestore copy of the documents read answers [watch] after an offline
/// cold start.
final class FirestoreRoundLedger implements RoundLedger {
  const FirestoreRoundLedger(this._db);

  final FirebaseFirestore _db;

  /// Asks the server first, then creates the document only when it has
  /// none, and waits for the server's answer (offline, for as long as it
  /// takes).
  ///
  /// Why not a plain `set`: the security rules take a summary only as the
  /// document's creation. After a kill, an earlier `set` of this summary
  /// may still be in Firestore's own queue, or already on the server; a
  /// second `set` would then reach it as an update and be refused, though
  /// the server has the summary. So the server's word comes first: a
  /// listener's first snapshot that is neither from the phone's copy nor
  /// waiting on a write of this phone ([isServerWord]), which, after a
  /// kill, is the earlier write kept or refused. The document there means
  /// kept; none means never written, or refused, and it is created now.
  ///
  /// Any error of Firestore (the member removed cannot even read) is a
  /// refusal: « Réessayer » asks again.
  @override
  Future<LedgerAnswer> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async {
    final document = FirestoreLayout.roundsOf(
      _db,
      sector,
      campaign,
    ).doc(summary.id.value);
    try {
      final known = await document
          .snapshots(includeMetadataChanges: true)
          .firstWhere((snapshot) => isServerWord(snapshot.metadata));
      if (!known.exists) await document.set(roundToDocument(summary));
      return LedgerAnswer.kept;
    } on FirebaseException catch (error) {
      debugPrint('Round ${summary.id.value} refused: $error');
      return LedgerAnswer.refused;
    }
  }

  /// The document's first snapshot: the phone's copy at once when it has
  /// one (offline too), else the server's. Unreadable or refused, none.
  @override
  Future<RoundSummary?> find(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
  ) async {
    try {
      final snapshot = await _document(
        sector,
        campaign,
        round,
      ).snapshots().first;
      final data = snapshot.data();
      return data == null ? null : roundFromDocument(snapshot.id, data);
    } on FirebaseException catch (error) {
      debugPrint('Round ${round.value} not read: $error');
      return null;
    } on FormatException catch (error) {
      debugPrint('Round ${round.value} unreadable: $error');
      return null;
    }
  }

  /// An `update` of the correction's own fields, not a `set` of the whole
  /// summary: the rules tell a correction from a summary sent again by
  /// them (a `set` of the summary would wipe the correction). Firestore
  /// applies it to the phone's copy at once and sends it when it can, so
  /// it is not waited for; a refusal is only logged.
  @override
  Future<void> correct(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    RoundCorrected correction,
  ) async => sendInBackground(
    'correct round ${round.value}',
    _document(sector, campaign, round).update(correctionToUpdate(correction)),
  );

  /// Increments rather than the figures themselves: two phones settling
  /// one house each both count, and the rules check « one fewer » against
  /// what the server has. Sent as [correct] is.
  @override
  Future<void> settleForgottenHouse(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
    ForgottenHouse settled,
  ) async => sendInBackground(
    'settle a house of round ${round.value}',
    _document(sector, campaign, round).update(forgottenHouseToUpdate(settled)),
  );

  DocumentReference<Map<String, dynamic>> _document(
    SectorId sector,
    CampaignYear campaign,
    RoundId round,
  ) => FirestoreLayout.roundsOf(_db, sector, campaign).doc(round.value);

  /// Follows `rounds/` with a listener, served from the phone's copy
  /// first. Refused (the member was removed, or left), it gives none, as
  /// the other listeners take it.
  @override
  Stream<List<RoundSummary>> watch(SectorId sector, CampaignYear campaign) =>
      FirestoreLayout.roundsOf(_db, sector, campaign)
          .snapshots()
          .map(
            (snapshot) => roundsFromDocuments({
              for (final doc in snapshot.docs) doc.id: doc.data(),
            }),
          )
          .transform(
            StreamTransformer.fromHandlers(
              handleError: (error, trace, sink) {
                if (isNoLongerReadable(error)) {
                  sink.add(const []);
                } else {
                  sink.addError(error, trace);
                }
              },
            ),
          );
}

/// Whether a snapshot of [metadata] is the server's word on a document:
/// read from the server, with no write of this phone waiting on it.
bool isServerWord(SnapshotMetadata metadata) =>
    !metadata.isFromCache && !metadata.hasPendingWrites;
