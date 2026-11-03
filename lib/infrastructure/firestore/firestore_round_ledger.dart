import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/round_document_mapper.dart';

/// The [RoundLedger] over Firestore: one document per validated tournée,
/// `sectors/{id}/campaigns/{year}/rounds/{roundId}` (PLAN §6.2), seen by
/// the whole secteur in « Collecte ».
///
/// Nothing of it is kept in a file of its own: Firestore's offline
/// persistence keeps a summary recorded offline in its queue, across
/// restarts, until the server has it, and its copy of the documents read
/// answers [watch] after an offline cold start.
final class FirestoreRoundLedger implements RoundLedger {
  const FirestoreRoundLedger(this._db);

  final FirebaseFirestore _db;

  /// Writes the summary under its round's id, without waiting for the
  /// server (`sendInBackground`): the phone's copy has it at once.
  ///
  /// A `set`, which the security rules accept only as the document's
  /// creation. Recording the same tournée again (validated twice after a
  /// kill) reaches the server as an update, which they refuse: Firestore
  /// then puts the phone's copy back to the first summary, which stays.
  @override
  Future<void> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async {
    sendInBackground(
      'round ${summary.id.value}',
      FirestoreLayout.roundsOf(
        _db,
        sector,
        campaign,
      ).doc(summary.id.value).set(roundToDocument(summary)),
    );
  }

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
