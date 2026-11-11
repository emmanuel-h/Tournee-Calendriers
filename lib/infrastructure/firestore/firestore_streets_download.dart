import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

/// The [StreetsDownload] of Firestore: one read of the whole streets
/// collection of a campaign (PLAN §6.2), asked of the server
/// (`Source.server`). Every document read lands in Firestore's cache on
/// the phone, which has no size limit (`offlineFirestore`), so the
/// tournée's listener answers from it after an offline cold start
/// (PLAN §7).
final class FirestoreStreetsDownload implements StreetsDownload {
  const FirestoreStreetsDownload(this._db);

  final FirebaseFirestore _db;

  @override
  Future<Result<List<Street>, StreetsDownloadFailure>> fromServer(
    SectorId sector,
    CampaignYear campaign,
  ) async {
    try {
      final snapshot = await FirestoreLayout.streetsOf(
        _db,
        sector,
        campaign,
      ).get(const GetOptions(source: Source.server));
      return Ok([for (final doc in snapshot.docs) ?_read(doc)]);
    } on FirebaseException catch (error) {
      return Err(
        isNoNetwork(error)
            ? StreetsDownloadFailure.noNetwork
            : StreetsDownloadFailure.serviceError,
      );
    }
  }

  /// The street in [doc], or null when it cannot be read: it is left out
  /// of the map's area rather than stopping the download. Its document is
  /// in the phone's cache all the same, so the tournée's listener lists it
  /// on Accueil as unreadable, offline too (#149).
  Street? _read(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return streetFromDocument(doc.id, doc.data());
    } on FormatException catch (error) {
      debugPrint('Unreadable street ${doc.id}: $error');
      return null;
    }
  }
}
