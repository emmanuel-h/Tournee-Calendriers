import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/campaign_store.dart';
import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/campaign_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

/// The [CampaignStore] over Firestore (PLAN §5.10, §6.2): what an admin's
/// phone writes to start a new campaign. Everything is read from the
/// server (`Source.server`) and written in batches that are awaited, so
/// offline it fails at once instead of waiting in Firestore's queue, and a
/// step done is on the server before the next one starts.
///
/// - **Copies** go [copiesPerBatch] at a time: the security rules check
///   each copy against its street of the current campaign, one document
///   read per copy, and a batch may read at most 20 documents
///   (`isStreetCopy` in `firebase/firestore.rules`). The new campaign's
///   document goes in the first batch: the rules want it there for each
///   copy.
/// - **The switch** is a transaction: it reads the secteur, so a secteur
///   another admin moved meanwhile is left as it is, and moves it with its
///   join preview in one write (the rules require both).
/// - **Deleting** a year goes [writesPerBatch] documents at a time, the
///   streets and the validated tournées first, the campaign's document
///   last: a cut leaves it there, so the next try finds the year again.
final class FirestoreCampaignStore implements CampaignStore {
  const FirestoreCampaignStore(this._db);

  /// The most street copies in one batch: the admin, the secteur, the new
  /// campaign and one street per copy make at most 18 of the 20 documents
  /// a batch may read (measured in the emulator: 17 copies pass, 18 do
  /// not), and 15 streets of 80 KB stay far below the 10 MB of a request.
  static const copiesPerBatch = 15;

  /// The most writes in one batch (Firestore's limit).
  static const writesPerBatch = 500;

  static const _server = GetOptions(source: Source.server);

  final FirebaseFirestore _db;

  @override
  Future<Result<List<Street>, CampaignFailure>> streetsOf(
    SectorId sector,
    CampaignYear campaign,
  ) => _asked(() async {
    final docs = await FirestoreLayout.streetsOf(
      _db,
      sector,
      campaign,
    ).get(_server);
    final streets = <Street>[];
    for (final doc in docs.docs) {
      try {
        streets.add(streetFromDocument(doc.id, doc.data()));
      } on FormatException catch (error) {
        // An unreadable street (#149) cannot be copied: the new year goes
        // on without it, as the map and the totals already do.
        debugPrint('Street ${doc.id} not copied: $error');
      }
    }
    return List<Street>.unmodifiable(streets);
  });

  @override
  Future<Result<void, CampaignFailure>> writeCopies(
    SectorId sector, {
    required CampaignYear from,
    required CampaignYear to,
    required List<Street> streets,
  }) => _asked(() async {
    final campaign = FirestoreLayout.campaignOf(_db, sector, to);
    final copies = FirestoreLayout.streetsOf(_db, sector, to);
    // Written by an earlier try when it is there: a `set` over it would be
    // an update, which the rules do not allow on a campaign.
    final written = (await campaign.get(_server)).exists;
    final stored = await copies.get(_server);
    final chunks = [
      for (var start = 0; start < streets.length; start += copiesPerBatch)
        streets.skip(start).take(copiesPerBatch),
    ];
    // A secteur without street still gets its campaign: one batch, empty
    // of copies.
    if (chunks.isEmpty) chunks.add(const []);
    for (final (index, chunk) in chunks.indexed) {
      final batch = _db.batch();
      if (index == 0 && !written) {
        batch.set(campaign, nextCampaignDocument(from: from));
      }
      for (final street in chunk) {
        batch.set(copies.doc(street.id.value), streetToDocument(street));
      }
      await batch.commit();
    }
    // A street copied by an earlier try that is no longer to copy: deleted
    // or put in the Corbeille meanwhile.
    final kept = {for (final street in streets) street.id.value};
    await _deleteAll([
      for (final doc in stored.docs)
        if (!kept.contains(doc.id)) doc.reference,
    ]);
  });

  @override
  Future<Result<void, CampaignFailure>> switchTo(
    SectorId sector,
    CampaignYear year,
  ) => _asked(
    () => _db.runTransaction<void>((transaction) async {
      final sectorDoc = FirestoreLayout.sector(_db, sector);
      final data = (await transaction.get(sectorDoc)).data();
      final current = currentCampaignOf(data);
      // Deleted meanwhile, or moved there (or further) by another admin.
      if (data == null || current == null || current.value >= year.value) {
        return;
      }
      transaction
        ..update(sectorDoc, campaignSwitchFields(year))
        ..update(
          _db.collection(FirestoreLayout.joinCodes).doc('${data['joinCode']}'),
          previewCampaignFields(year),
        );
    }),
  );

  /// Lists the campaigns, then asks each one for a single validated
  /// tournée: one is enough to keep the year.
  @override
  Future<Result<List<CampaignRecord>, CampaignFailure>> campaignsOf(
    SectorId sector,
  ) => _asked(() async {
    final campaigns = await FirestoreLayout.sector(
      _db,
      sector,
    ).collection(FirestoreLayout.campaigns).get(_server);
    final records = <CampaignRecord>[];
    for (final doc in campaigns.docs) {
      final year = campaignYearOf(doc.id);
      if (year == null) continue;
      final rounds = await FirestoreLayout.roundsOf(
        _db,
        sector,
        year,
      ).limit(1).get(_server);
      records.add(
        CampaignRecord(year: year, hasValidatedRound: rounds.docs.isNotEmpty),
      );
    }
    return List<CampaignRecord>.unmodifiable(records);
  });

  @override
  Future<Result<void, CampaignFailure>> delete(
    SectorId sector,
    Set<CampaignYear> years,
  ) => _asked(() async {
    for (final year in years) {
      final listed = await Future.wait([
        FirestoreLayout.streetsOf(_db, sector, year).get(_server),
        FirestoreLayout.roundsOf(_db, sector, year).get(_server),
      ]);
      await _deleteAll([
        for (final list in listed)
          for (final doc in list.docs) doc.reference,
        FirestoreLayout.campaignOf(_db, sector, year),
      ]);
    }
  });

  /// Deletes [docs] in batches, in their order.
  Future<void> _deleteAll(
    List<DocumentReference<Map<String, dynamic>>> docs,
  ) async {
    for (var start = 0; start < docs.length; start += writesPerBatch) {
      final batch = _db.batch();
      for (final doc in docs.skip(start).take(writesPerBatch)) {
        batch.delete(doc);
      }
      await batch.commit();
    }
  }

  /// Runs [step] against the server: offline it fails with
  /// [CampaignFailure.noNetwork], refused by the security rules with
  /// [CampaignFailure.notAdmin]. Any other failure is thrown: the user can
  /// do nothing about it.
  Future<Result<T, CampaignFailure>> _asked<T>(
    Future<T> Function() step,
  ) async {
    try {
      return Ok(await step());
    } on FirebaseException catch (error) {
      if (campaignFailureOf(error) case final failure?) return Err(failure);
      rethrow;
    }
  }
}

/// What [error] of a step of a new campaign tells the use case: no
/// network, or not an admin (the security rules refused). Null for any
/// other failure, which the user can do nothing about.
CampaignFailure? campaignFailureOf(FirebaseException error) {
  if (isNoNetwork(error)) return CampaignFailure.noNetwork;
  if (isRefused(error)) return CampaignFailure.notAdmin;
  return null;
}
